// wreq pulls BoringSSL in through btls-sys, which emits its static
// `crypto`/`ssl` archives in a single left-to-right link pass. With this
// crate's `lto = true`, the exact set of BoringSSL symbols referenced
// directly by Rust code shifts from build to build, so `ssl` objects can
// end up referencing `crypto` members (X509_free, SSL_CTX_free, …) that
// the one-pass archive scan already walked past — leaving them undefined
// and crashing `dlopen("libburrow.so")` on the device.
//
// Forcing both archives in whole (every object, unconditionally) makes
// the link deterministic: all BoringSSL symbols are present regardless of
// reference order. The cdylib version script still hides them, so nothing
// new is exported and there is no clash with other libraries.
fn main() {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_os == "android" {
        println!("cargo:rustc-link-lib=static:+whole-archive=crypto");
        println!("cargo:rustc-link-lib=static:+whole-archive=ssl");
    }
}
