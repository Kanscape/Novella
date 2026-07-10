//! In-memory BlurHash → RGBA8888 像素解码，供 Flutter 占位图使用。
//!
//! 纯 CPU 计算，经 flutter_rust_bridge 在其 worker 线程执行，脱离 Dart UI isolate。
//! 内存由 Dart 管理：返回的 `Vec<u8>` 被 FRB 拷入 Dart 拥有的 `Uint8List` 后，
//! Rust 端临时缓冲随即释放——无手动 Rust 内存、无泄漏。
//!
//! 数值实现与 `packages/flutter_blurhash` 的标准 Dart 解码逐位对齐（f64 运算）。

use anyhow::{anyhow, Result};

const DIGITS: &[u8] =
    b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~";

fn decode83(s: &[u8]) -> Result<u32> {
    let mut value: u32 = 0;
    for &c in s {
        let digit = DIGITS
            .iter()
            .position(|&d| d == c)
            .ok_or_else(|| anyhow!("invalid base83 character"))?;
        value = value * 83 + digit as u32;
    }
    Ok(value)
}

fn srgb_to_linear(value: u32) -> f64 {
    let v = value as f64 / 255.0;
    if v <= 0.04045 {
        v / 12.92
    } else {
        ((v + 0.055) / 1.055).powf(2.4)
    }
}

fn linear_to_srgb(value: f64) -> u8 {
    let v = value.clamp(0.0, 1.0);
    let e = if v <= 0.0031308 {
        v * 12.92 * 255.0
    } else {
        (1.055 * v.powf(1.0 / 2.4) - 0.055) * 255.0
    };
    // 与 Dart 一致：(e + 0.5).round()
    ((e + 0.5).round() as i32).clamp(0, 255) as u8
}

fn sign_pow(val: f64, exp: f64) -> f64 {
    let sign = if val < 0.0 { -1.0 } else { 1.0 };
    sign * val.abs().powf(exp)
}

fn decode_dc(value: u32) -> [f64; 3] {
    let r = value >> 16;
    let g = (value >> 8) & 255;
    let b = value & 255;
    [srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)]
}

fn decode_ac(value: u32, maximum_value: f64) -> [f64; 3] {
    let quant_r = (value as f64 / (19.0 * 19.0)).floor();
    let quant_g = (value as f64 / 19.0).floor() % 19.0;
    let quant_b = (value % 19) as f64;
    [
        sign_pow((quant_r - 9.0) / 9.0, 2.0) * maximum_value,
        sign_pow((quant_g - 9.0) / 9.0, 2.0) * maximum_value,
        sign_pow((quant_b - 9.0) / 9.0, 2.0) * maximum_value,
    ]
}

/// 将 BlurHash 字符串解码为 `width x height` 的 RGBA8888 像素（每像素 4 字节，alpha=255）。
///
/// FRB 会把返回的 `Vec<u8>` 拷入 Dart `Uint8List`；Dart 侧再交给
/// `ui.decodeImageFromPixels` 生成 `ui.Image`。
#[flutter_rust_bridge::frb]
pub fn blur_hash_decode_rgba(
    blur_hash: String,
    width: u32,
    height: u32,
    punch: f64,
) -> Result<Vec<u8>> {
    let bytes = blur_hash.as_bytes();
    if bytes.len() < 6 {
        return Err(anyhow!("blurhash must be at least 6 characters"));
    }

    let size_flag = decode83(&bytes[0..1])?;
    let num_y = (size_flag / 9) + 1;
    let num_x = (size_flag % 9) + 1;

    let expected_len = 4 + 2 * num_x * num_y;
    if bytes.len() as u32 != expected_len {
        return Err(anyhow!(
            "blurhash length mismatch: got {}, expected {}",
            bytes.len(),
            expected_len
        ));
    }

    let quantised_maximum_value = decode83(&bytes[1..2])?;
    let maximum_value = (quantised_maximum_value as f64 + 1.0) / 166.0;

    let count = (num_x * num_y) as usize;
    let mut colors = vec![[0f64; 3]; count];
    colors[0] = decode_dc(decode83(&bytes[2..6])?);
    for i in 1..count {
        let start = 4 + i * 2;
        let value = decode83(&bytes[start..start + 2])?;
        colors[i] = decode_ac(value, maximum_value * punch);
    }

    let w = width as usize;
    let h = height as usize;
    let num_x = num_x as usize;
    let num_y = num_y as usize;

    let mut pixels = vec![0u8; w * h * 4];
    let mut p = 0;
    for y in 0..h {
        for x in 0..w {
            let mut r = 0f64;
            let mut g = 0f64;
            let mut b = 0f64;
            for j in 0..num_y {
                for i in 0..num_x {
                    let basis = ((std::f64::consts::PI * x as f64 * i as f64) / width as f64).cos()
                        * ((std::f64::consts::PI * y as f64 * j as f64) / height as f64).cos();
                    let color = colors[i + j * num_x];
                    r += color[0] * basis;
                    g += color[1] * basis;
                    b += color[2] * basis;
                }
            }
            pixels[p] = linear_to_srgb(r);
            pixels[p + 1] = linear_to_srgb(g);
            pixels[p + 2] = linear_to_srgb(b);
            pixels[p + 3] = 255;
            p += 4;
        }
    }

    Ok(pixels)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decodes_expected_size() {
        // 标准示例 blurhash（27 字符 → 4x3 分量）。
        let hash = "LEHV6nWB2yk8pyo0adR*.7kCMdnj".to_string();
        let px = blur_hash_decode_rgba(hash, 32, 48, 1.0).unwrap();
        assert_eq!(px.len(), 32 * 48 * 4);
        // alpha 全为 255
        assert!(px.iter().skip(3).step_by(4).all(|&a| a == 255));
    }

    #[test]
    fn rejects_bad_length() {
        assert!(blur_hash_decode_rgba("abc".to_string(), 4, 4, 1.0).is_err());
    }
}
