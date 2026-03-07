mod api;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

pub use api::*;

/// Keep a stable symbol for iOS static linking.
#[no_mangle]
pub extern "C" fn dummy_method_to_enforce_bundling() -> i32 {
    42
}
