//! WOFF2 to TTF font converter for Flutter integration.
//!
//! This module provides in-memory conversion of WOFF2 font data to TTF format,
//! which can then be loaded by Flutter's FontLoader on all platforms.

use anyhow::{anyhow, Result};
use ttf_parser::Face;

/// Convert WOFF2 bytes to TTF bytes.
///
/// This is a pure in-memory operation - no file I/O is performed.
///
/// # Arguments
/// * `woff2_data` - Raw WOFF2 font bytes (e.g., downloaded from server)
///
/// # Returns
/// * `Ok(Vec<u8>)` - TTF font bytes ready for FontLoader
/// * `Err(_)` - If WOFF2 decoding fails
///
/// # Example (Dart side)
/// ```dart
/// final ttfBytes = await convertWoff2ToTtf(woff2Data: woff2Bytes);
/// final fontLoader = FontLoader('MyFont');
/// fontLoader.addFont(Future.value(ByteData.view(ttfBytes.buffer)));
/// await fontLoader.load();
/// ```
#[flutter_rust_bridge::frb]
pub fn convert_woff2_to_ttf(woff2_data: Vec<u8>) -> Result<Vec<u8>> {
    if woff2_data.is_empty() {
        return Err(anyhow!("Empty WOFF2 data"));
    }

    // Validate WOFF2 signature: 'wOF2' (0x774F4632)
    if woff2_data.len() < 4
        || woff2_data[0] != 0x77
        || woff2_data[1] != 0x4F
        || woff2_data[2] != 0x46
        || woff2_data[3] != 0x32
    {
        return Err(anyhow!("Invalid WOFF2 signature"));
    }

    // Perform conversion using woofwoof crate
    // decompress returns Option<Vec<u8>>
    woofwoof::decompress(&woff2_data).ok_or_else(|| anyhow!("WOFF2 decode failed"))
}

/// Find code points that map to zero-advance, empty glyphs in a TTF font.
///
/// These are effectively invisible placeholders in the obfuscation font.
/// Web rendering swallows them naturally, but Flutter may leave visible holes.
#[flutter_rust_bridge::frb]
pub fn extract_invisible_codepoints(ttf_data: Vec<u8>) -> Result<Vec<u32>> {
    if ttf_data.is_empty() {
        return Err(anyhow!("Empty TTF data"));
    }

    let face = Face::parse(&ttf_data, 0).map_err(|_| anyhow!("Invalid TTF data"))?;
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

        if advance != 0 {
            continue;
        }

        if face.glyph_bounding_box(glyph_id).is_none() {
            invisible.push(codepoint);
        }
    }

    Ok(invisible)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_empty_input() {
        let result = convert_woff2_to_ttf(vec![]);
        assert!(result.is_err());
    }

    #[test]
    fn test_invalid_signature() {
        let result = convert_woff2_to_ttf(vec![0x00, 0x01, 0x00, 0x00]);
        assert!(result.is_err());
    }

    #[test]
    fn test_extract_invisible_codepoints_rejects_empty_input() {
        let result = extract_invisible_codepoints(vec![]);
        assert!(result.is_err());
    }
}
