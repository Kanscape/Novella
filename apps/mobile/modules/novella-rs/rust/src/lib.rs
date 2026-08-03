use std::slice;

use anyhow::{anyhow, Result};
use ttf_parser::Face;

#[repr(C)]
pub struct NovellaBuffer {
    pub ptr: *mut u8,
    pub len: usize,
}

impl NovellaBuffer {
    fn empty() -> Self {
        Self {
            ptr: std::ptr::null_mut(),
            len: 0,
        }
    }
}

fn into_buffer(mut bytes: Vec<u8>) -> NovellaBuffer {
    let buffer = NovellaBuffer {
        ptr: bytes.as_mut_ptr(),
        len: bytes.len(),
    };
    std::mem::forget(bytes);
    buffer
}

fn convert_woff2_to_ttf(woff2_data: &[u8]) -> Result<Vec<u8>> {
    if woff2_data.is_empty() {
        return Err(anyhow!("Empty WOFF2 data"));
    }
    if woff2_data.len() < 4 || &woff2_data[..4] != b"wOF2" {
        return Err(anyhow!("Invalid WOFF2 signature"));
    }
    let ttf = woofwoof::decompress(woff2_data).ok_or_else(|| anyhow!("WOFF2 decode failed"))?;
    ensure_font_names(ttf)
}

const SFNT_CHECKSUM_MAGIC: u32 = 0xB1B0_AFBA;

#[derive(Clone, Copy)]
struct SfntTableRecord {
    record_offset: usize,
    table_offset: usize,
    length: usize,
}

fn ensure_font_names(mut font: Vec<u8>) -> Result<Vec<u8>> {
    if has_required_font_names(&font)? {
        return Ok(font);
    }

    let name_record = find_sfnt_table(&font, b"name")?;
    let head_record = find_sfnt_table(&font, b"head")?;
    if head_record.length < 12 {
        return Err(anyhow!("Invalid head table"));
    }

    let family = format!("NovellaReader-{:016X}", fnv1a64(&font));
    let name_table = build_name_table(&family)?;

    while font.len() % 4 != 0 {
        font.push(0);
    }
    let name_offset = font.len();
    font.extend_from_slice(&name_table);
    while font.len() % 4 != 0 {
        font.push(0);
    }

    write_u32(
        &mut font,
        name_record.record_offset + 4,
        table_checksum(&name_table)?,
    )?;
    write_u32(
        &mut font,
        name_record.record_offset + 8,
        u32::try_from(name_offset).map_err(|_| anyhow!("Font is too large"))?,
    )?;
    write_u32(
        &mut font,
        name_record.record_offset + 12,
        u32::try_from(name_table.len()).map_err(|_| anyhow!("Name table is too large"))?,
    )?;

    // OpenType calculates the head table checksum with checkSumAdjustment set
    // to zero, then writes the whole-font adjustment afterwards.
    write_u32(&mut font, head_record.table_offset + 8, 0)?;
    let head_end = head_record
        .table_offset
        .checked_add(head_record.length)
        .ok_or_else(|| anyhow!("Invalid head table range"))?;
    let head = font
        .get(head_record.table_offset..head_end)
        .ok_or_else(|| anyhow!("Invalid head table range"))?;
    let head_checksum = table_checksum(head)?;
    write_u32(&mut font, head_record.record_offset + 4, head_checksum)?;

    let adjustment = SFNT_CHECKSUM_MAGIC.wrapping_sub(table_checksum(&font)?);
    write_u32(&mut font, head_record.table_offset + 8, adjustment)?;
    Ok(font)
}

fn has_required_font_names(font: &[u8]) -> Result<bool> {
    let record = find_sfnt_table(font, b"name")?;
    let table_end = record
        .table_offset
        .checked_add(record.length)
        .ok_or_else(|| anyhow!("Invalid name table range"))?;
    let table = font
        .get(record.table_offset..table_end)
        .ok_or_else(|| anyhow!("Invalid name table range"))?;
    if table.len() < 6 {
        return Ok(false);
    }

    let count = usize::from(read_u16(table, 2)?);
    let storage_offset = usize::from(read_u16(table, 4)?);
    let records_end = 6usize
        .checked_add(
            count
                .checked_mul(12)
                .ok_or_else(|| anyhow!("Invalid name record count"))?,
        )
        .ok_or_else(|| anyhow!("Invalid name record count"))?;
    if records_end > table.len() || storage_offset > table.len() {
        return Ok(false);
    }

    let mut has_family = false;
    let mut has_postscript = false;
    for index in 0..count {
        let offset = 6 + index * 12;
        let name_id = read_u16(table, offset + 6)?;
        let length = usize::from(read_u16(table, offset + 8)?);
        let string_offset = usize::from(read_u16(table, offset + 10)?);
        let string_end = storage_offset
            .checked_add(string_offset)
            .and_then(|start| start.checked_add(length));
        let valid = length > 0 && string_end.is_some_and(|end| end <= table.len());
        if valid && name_id == 1 {
            has_family = true;
        }
        if valid && name_id == 6 {
            has_postscript = true;
        }
    }
    Ok(has_family && has_postscript)
}

fn build_name_table(family: &str) -> Result<Vec<u8>> {
    let entries = [
        (1u16, family.to_owned()),
        (2, "Regular".to_owned()),
        (3, format!("{family};1.0")),
        (4, family.to_owned()),
        (5, "Version 1.0".to_owned()),
        (6, family.to_owned()),
    ];
    let count = u16::try_from(entries.len()).map_err(|_| anyhow!("Too many font names"))?;
    let storage_offset = 6usize + entries.len() * 12;
    let mut table = Vec::with_capacity(storage_offset + 256);
    push_u16(&mut table, 0);
    push_u16(&mut table, count);
    push_u16(
        &mut table,
        u16::try_from(storage_offset).map_err(|_| anyhow!("Name table is too large"))?,
    );

    let mut storage = Vec::new();
    for (name_id, value) in entries {
        let mut encoded = Vec::with_capacity(value.len() * 2);
        for unit in value.encode_utf16() {
            encoded.extend_from_slice(&unit.to_be_bytes());
        }
        push_u16(&mut table, 3); // Windows
        push_u16(&mut table, 1); // Unicode BMP
        push_u16(&mut table, 0x0409); // English (United States)
        push_u16(&mut table, name_id);
        push_u16(
            &mut table,
            u16::try_from(encoded.len()).map_err(|_| anyhow!("Font name is too long"))?,
        );
        push_u16(
            &mut table,
            u16::try_from(storage.len()).map_err(|_| anyhow!("Name storage is too large"))?,
        );
        storage.extend_from_slice(&encoded);
    }
    table.extend_from_slice(&storage);
    Ok(table)
}

fn find_sfnt_table(font: &[u8], tag: &[u8; 4]) -> Result<SfntTableRecord> {
    if font.len() < 12 {
        return Err(anyhow!("Invalid sfnt header"));
    }
    let table_count = usize::from(read_u16(font, 4)?);
    let directory_end = 12usize
        .checked_add(
            table_count
                .checked_mul(16)
                .ok_or_else(|| anyhow!("Invalid table count"))?,
        )
        .ok_or_else(|| anyhow!("Invalid table count"))?;
    if directory_end > font.len() {
        return Err(anyhow!("Invalid sfnt table directory"));
    }

    for index in 0..table_count {
        let record_offset = 12 + index * 16;
        if font.get(record_offset..record_offset + 4) != Some(tag.as_slice()) {
            continue;
        }
        let table_offset = usize::try_from(read_u32(font, record_offset + 8)?)
            .map_err(|_| anyhow!("Invalid table offset"))?;
        let length = usize::try_from(read_u32(font, record_offset + 12)?)
            .map_err(|_| anyhow!("Invalid table length"))?;
        let table_end = table_offset
            .checked_add(length)
            .ok_or_else(|| anyhow!("Invalid table range"))?;
        if table_end > font.len() {
            return Err(anyhow!("Invalid table range"));
        }
        return Ok(SfntTableRecord {
            record_offset,
            table_offset,
            length,
        });
    }
    Err(anyhow!("Required sfnt table is missing"))
}

fn fnv1a64(bytes: &[u8]) -> u64 {
    let mut hash = 0xcbf2_9ce4_8422_2325u64;
    for byte in bytes {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(0x0000_0100_0000_01b3);
    }
    hash
}

fn table_checksum(bytes: &[u8]) -> Result<u32> {
    let mut checksum = 0u32;
    for chunk in bytes.chunks(4) {
        let mut word = [0u8; 4];
        word[..chunk.len()].copy_from_slice(chunk);
        checksum = checksum.wrapping_add(u32::from_be_bytes(word));
    }
    Ok(checksum)
}

fn read_u16(bytes: &[u8], offset: usize) -> Result<u16> {
    let value = bytes
        .get(offset..offset + 2)
        .ok_or_else(|| anyhow!("Unexpected end of font data"))?;
    Ok(u16::from_be_bytes([value[0], value[1]]))
}

fn read_u32(bytes: &[u8], offset: usize) -> Result<u32> {
    let value = bytes
        .get(offset..offset + 4)
        .ok_or_else(|| anyhow!("Unexpected end of font data"))?;
    Ok(u32::from_be_bytes([value[0], value[1], value[2], value[3]]))
}

fn write_u32(bytes: &mut [u8], offset: usize, value: u32) -> Result<()> {
    let target = bytes
        .get_mut(offset..offset + 4)
        .ok_or_else(|| anyhow!("Unexpected end of font data"))?;
    target.copy_from_slice(&value.to_be_bytes());
    Ok(())
}

fn push_u16(bytes: &mut Vec<u8>, value: u16) {
    bytes.extend_from_slice(&value.to_be_bytes());
}

fn extract_invisible_codepoints(ttf_data: &[u8]) -> Result<Vec<u32>> {
    if ttf_data.is_empty() {
        return Err(anyhow!("Empty TTF data"));
    }
    let face = Face::parse(ttf_data, 0).map_err(|_| anyhow!("Invalid TTF data"))?;
    let mut invisible = Vec::new();

    for codepoint in 0..=0x10FFFF {
        let Some(ch) = char::from_u32(codepoint) else {
            continue;
        };
        let Some(glyph_id) = face.glyph_index(ch) else {
            continue;
        };
        let Some(advance) = face.glyph_hor_advance(glyph_id) else {
            continue;
        };
        if advance == 0 && face.glyph_bounding_box(glyph_id).is_none() {
            invisible.push(codepoint);
        }
    }

    Ok(invisible)
}

#[no_mangle]
pub extern "C" fn novella_rs_convert_woff2_to_ttf(data: *const u8, len: usize) -> NovellaBuffer {
    if data.is_null() {
        return NovellaBuffer::empty();
    }
    let input = unsafe { slice::from_raw_parts(data, len) };
    convert_woff2_to_ttf(input)
        .map(into_buffer)
        .unwrap_or_else(|_| NovellaBuffer::empty())
}

#[no_mangle]
pub extern "C" fn novella_rs_extract_invisible_codepoints(
    data: *const u8,
    len: usize,
) -> NovellaBuffer {
    if data.is_null() {
        return NovellaBuffer::empty();
    }
    let input = unsafe { slice::from_raw_parts(data, len) };
    extract_invisible_codepoints(input)
        .map(|values| {
            let mut bytes = Vec::with_capacity(values.len() * std::mem::size_of::<u32>());
            for value in values {
                bytes.extend_from_slice(&value.to_le_bytes());
            }
            bytes
        })
        .map(into_buffer)
        .unwrap_or_else(|_| NovellaBuffer::empty())
}

#[no_mangle]
pub extern "C" fn novella_rs_free_buffer(buffer: NovellaBuffer) {
    if buffer.ptr.is_null() || buffer.len == 0 {
        return;
    }
    unsafe {
        drop(Vec::from_raw_parts(buffer.ptr, buffer.len, buffer.len));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn unnamed_test_font() -> Vec<u8> {
        let mut font = Vec::new();
        font.extend_from_slice(&0x0001_0000u32.to_be_bytes());
        push_u16(&mut font, 2);
        push_u16(&mut font, 32);
        push_u16(&mut font, 1);
        push_u16(&mut font, 0);

        font.extend_from_slice(b"head");
        font.extend_from_slice(&0u32.to_be_bytes());
        font.extend_from_slice(&44u32.to_be_bytes());
        font.extend_from_slice(&54u32.to_be_bytes());

        font.extend_from_slice(b"name");
        font.extend_from_slice(&0u32.to_be_bytes());
        font.extend_from_slice(&100u32.to_be_bytes());
        font.extend_from_slice(&6u32.to_be_bytes());

        font.extend_from_slice(&[0; 54]);
        font.extend_from_slice(&[0; 2]);
        font.extend_from_slice(&[0, 0, 0, 0, 0, 6]);
        font.extend_from_slice(&[0; 2]);
        font
    }

    #[test]
    fn rejects_invalid_font() {
        assert!(convert_woff2_to_ttf(&[]).is_err());
        assert!(convert_woff2_to_ttf(&[0, 1, 0, 0]).is_err());
    }

    #[test]
    fn adds_required_names_and_updates_font_checksum() {
        let font = unnamed_test_font();
        assert!(!has_required_font_names(&font).unwrap());

        let named = ensure_font_names(font).unwrap();
        assert!(has_required_font_names(&named).unwrap());
        assert_eq!(table_checksum(&named).unwrap(), SFNT_CHECKSUM_MAGIC);

        let unchanged = ensure_font_names(named.clone()).unwrap();
        assert_eq!(unchanged, named);
    }
}
