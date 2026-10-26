//! 100% Offline TOTP (RFC 6238 / RFC 4226) 2FA Authenticator Engine
//!
//! Computes 6-digit or 8-digit One-Time Passwords locally using the device clock
//! and HMAC-SHA1 / HMAC-SHA256 without any network access.

use hmac::{Hmac, Mac};
use sha1::Sha1;
use zeroize::Zeroizing;

type HmacSha1 = Hmac<Sha1>;

#[derive(Debug, Clone)]
pub struct TotpSnapshot {
    pub code: String,
    pub remaining_seconds: u8,
    pub period_seconds: u8,
}

/// Decodes an RFC 4648 Base32 secret string (case-insensitive, ignores spaces/hyphens)
/// into a `Zeroizing<Vec<u8>>` buffer.
pub fn decode_base32_secret(input: &str) -> Result<Zeroizing<Vec<u8>>, &'static str> {
    let mut buffer: u32 = 0;
    let mut bits_left: u8 = 0;
    let mut output = Vec::new();

    for ch in input.chars() {
        if ch == ' ' || ch == '-' || ch == '=' {
            continue;
        }
        let val: u32 = match ch.to_ascii_uppercase() {
            'A'..='Z' => (ch.to_ascii_uppercase() as u32) - ('A' as u32),
            '2'..='7' => (ch as u32) - ('2' as u32) + 26,
            _ => return Err("Invalid Base32 character in TOTP secret"),
        };

        buffer = (buffer << 5) | val;
        bits_left += 5;

        if bits_left >= 8 {
            bits_left -= 8;
            output.push(((buffer >> bits_left) & 0xFF) as u8);
        }
    }

    if output.is_empty() {
        return Err("Empty TOTP secret");
    }

    Ok(Zeroizing::new(output))
}

/// Generates an RFC 6238 TOTP 6-digit code for the given Unix timestamp (seconds).
pub fn generate_totp_sha1(
    base32_secret: &str,
    unix_timestamp_secs: u64,
    period_secs: u64,
    digits: u32,
) -> Result<TotpSnapshot, &'static str> {
    let secret_bytes = decode_base32_secret(base32_secret)?;
    let counter = unix_timestamp_secs / period_secs;
    let remaining = (period_secs - (unix_timestamp_secs % period_secs)) as u8;

    let counter_bytes = counter.to_be_bytes();
    let mut mac = HmacSha1::new_from_slice(&secret_bytes).map_err(|_| "HMAC key error")?;
    mac.update(&counter_bytes);
    let result = mac.finalize().into_bytes();

    // Dynamic Truncation per RFC 4226 Section 5.4
    let offset = (result[19] & 0x0f) as usize;
    let binary_code: u32 = ((result[offset] as u32 & 0x7f) << 24)
        | ((result[offset + 1] as u32 & 0xff) << 16)
        | ((result[offset + 2] as u32 & 0xff) << 8)
        | (result[offset + 3] as u32 & 0xff);

    let modulo = 10u32.pow(digits);
    let otp = binary_code % modulo;
    let formatted = format!("{:0width$}", otp, width = digits as usize);

    Ok(TotpSnapshot {
        code: formatted,
        remaining_seconds: remaining,
        period_seconds: period_secs as u8,
    })
}

