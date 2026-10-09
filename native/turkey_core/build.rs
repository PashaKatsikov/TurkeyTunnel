// wreq pulls BoringSSL in through btls-sys, which links its static
// `crypto`/`ssl` archives in a single left-to-right pass in crypto→ssl
// order. `ssl` objects reference `crypto` members (X509_free,
// SSL_CTX_free, …); because `crypto` is scanned *before* `ssl`, those
// members can be left undefined, and with this crate's `lto = true` the
// exact set that leaks shifts between builds — so `dlopen("libburrow.so")`
// crashed nondeterministically on device.
//
// Fix: append a second, grouped scan of the two archives at the very end
// of the link, in dependency order (ssl then crypto), wrapped in
// --start-group/--end-group so the linker keeps re-scanning until every
// cross-reference resolves. Unlike `+whole-archive`, this pulls only the
// members actually referenced, so it never force-loads unreferenced /
// malformed archive objects (e.g. BoringSSL's bio_ssl.cc.o, which the NDK
// build can emit as a non-ELF stub).
fn main() {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_os == "android" {
        for arg in [
            "-Wl,-Bstatic",
            "-Wl,--start-group",
            "-lssl",
            "-lcrypto",
            "-Wl,--end-group",
            "-Wl,-Bdynamic",
        ] {
            println!("cargo:rustc-link-arg={arg}");
        }
    }
}
