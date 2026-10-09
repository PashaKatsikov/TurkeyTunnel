//! Config POST.
//!
//! The attribution body arrives from Dart. The endpoint, the verb and
//! the header names are decrypted here, per call, and never returned
//! to Dart. The answer is the config's own JSON, unchanged.
//!
//! On Android the request leaves through a BoringSSL + Chrome TLS
//! fingerprint (`wreq`) so the upstream Cloudflare WAF treats it as a
//! real browser; a stock rustls/ureq handshake is fingerprinted and
//! blocked with a 403 challenge. Host builds (used by `flutter test`)
//! never touch the network, so they compile a stub that reports "no
//! transport" and avoids pulling a C/C++ TLS stack into the test build.

use std::ffi::CString;

const SEL_URL: u32 = 1;
const SEL_READ_SECS: u32 = 23;
const SEL_CONNECT_SECS: u32 = 27;
const SEL_METHOD: u32 = 42;
const SEL_HDR_ACCEPT: u32 = 43;
const SEL_HDR_TYPE: u32 = 44;
const SEL_MIME: u32 = 46;

#[cfg(target_os = "android")]
use crate::{expose, vault};

#[cfg(target_os = "android")]
fn reveal(sel: u32) -> String {
    String::from_utf8(expose(vault::raw(sel))).unwrap_or_default()
}

#[cfg(target_os = "android")]
fn secs(sel: u32, fallback: u64) -> u64 {
    reveal(sel).parse::<u64>().unwrap_or(fallback).clamp(1, 60)
}

fn pack(status: u16, body: &str) -> *mut std::ffi::c_char {
    let raw = format!("{status}\n{body}");
    let safe: Vec<u8> = raw.into_bytes().into_iter().filter(|&b| b != 0).collect();
    CString::new(safe)
        .unwrap_or_else(|_| CString::new("0\n").unwrap())
        .into_raw()
}

#[cfg(target_os = "android")]
fn borrowed<'a>(ptr: *const u8, len: usize) -> &'a [u8] {
    if ptr.is_null() || len == 0 {
        &[]
    } else {
        // SAFETY: the caller (Dart) keeps this buffer alive for the call.
        unsafe { std::slice::from_raw_parts(ptr, len) }
    }
}

/// POST [body] to the config endpoint and return `"{status}\n{body}"`.
/// A transport failure comes back as status 0. The caller frees the
/// pointer with `bw_free`. The `ua`/`ua_len` pair is accepted for ABI
/// stability; the browser emulation supplies its own matching
/// User-Agent so the TLS and header fingerprints stay consistent.
#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
pub extern "C" fn bw_ask(
    body: *const u8,
    body_len: usize,
    _ua: *const u8,
    _ua_len: usize,
) -> *mut std::ffi::c_char {
    use std::time::Duration;
    use wreq::Client;
    use wreq_util::Emulation;

    let url = reveal(SEL_URL);
    let method = reveal(SEL_METHOD);
    let accept = reveal(SEL_HDR_ACCEPT);
    let content = reveal(SEL_HDR_TYPE);
    let mime = reveal(SEL_MIME);
    if url.is_empty() || method.is_empty() || mime.is_empty() {
        return pack(0, "");
    }

    let payload = borrowed(body, body_len).to_vec();
    let connect = Duration::from_secs(secs(SEL_CONNECT_SECS, 8));
    let read = Duration::from_secs(secs(SEL_READ_SECS, 21));

    let runtime = match tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    {
        Ok(rt) => rt,
        Err(_) => return pack(0, ""),
    };

    runtime.block_on(async move {
        let client = match Client::builder()
            .emulation(Emulation::Chrome134)
            .connect_timeout(connect)
            .timeout(read)
            .build()
        {
            Ok(c) => c,
            Err(_) => return pack(0, ""),
        };

        let verb = wreq::Method::from_bytes(method.as_bytes())
            .unwrap_or(wreq::Method::POST);

        let reply = client
            .request(verb, &url)
            .header(accept.as_str(), mime.as_str())
            .header(content.as_str(), mime.as_str())
            .body(payload)
            .send()
            .await;

        match reply {
            Ok(resp) => {
                let status = resp.status().as_u16();
                let text = resp.text().await.unwrap_or_default();
                pack(status, &text)
            }
            Err(_) => pack(0, ""),
        }
    })
}

/// Host stub: no network transport is linked into test builds.
#[cfg(not(target_os = "android"))]
#[unsafe(no_mangle)]
pub extern "C" fn bw_ask(
    _body: *const u8,
    _body_len: usize,
    _ua: *const u8,
    _ua_len: usize,
) -> *mut std::ffi::c_char {
    let _ = (SEL_URL, SEL_READ_SECS, SEL_CONNECT_SECS, SEL_METHOD, SEL_HDR_ACCEPT, SEL_HDR_TYPE, SEL_MIME);
    pack(0, "")
}
