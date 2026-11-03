# macOS distribution verification, 1.1

The 1.0 executable had a linker-generated ad-hoc signature but no complete bundle resource seal. `codesign --verify --deep --strict` failed with “code has no resources but signature indicates they must be present”. Testing a local development launch did not catch the redistribution defect.

The revised build pipeline:

1. Exports a Universal 2 app containing `arm64` and `x86_64`.
2. Adds the runtime resources and full license notices.
3. Signs the entire bundle with the local ad-hoc identity, binding its Info.plist and resource files.
4. Runs `codesign --verify --all-architectures --deep --strict`.
5. Packages the sealed app into a read-only HFS+ / UDZO image and ZIP.
6. Runs `hdiutil verify` against the image.
7. Extracts the packaged filesystem for an independent content check, checks executable permissions, re-verifies the extracted app's resource signature and runs the extracted executable through a timed practice match.

The package includes an Applications shortcut and installation instructions. The app must be copied as a complete `.app` bundle; sharing only the executable omits the game pack.

The restricted build environment cannot attach a temporary `/dev/disk` device. The script's fallback builds HFS+ with `hdiutil makehybrid` and converts it to compressed UDIF with `hdiutil convert`, then verifies the resulting checksums. For package inspection here, the official 7-Zip CLI reads and extracts the HFS+ filesystem without mounting it. A mounted Finder test and a launch on the recipient's physical Mac are separate checks, not implied by CRC/signature verification.

## Integrity versus Apple approval

This build is ad-hoc signed and is **not Apple-notarized**. A valid resource signature proves that the packaged resources match the app seal; it is not a Developer ID certificate or a notarization ticket. Gatekeeper may still present its normal developer approval warning on another Mac. The package does not remove quarantine attributes or disable any system protection.

[Godot's macOS export documentation](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_macos.html) describes the available signing modes. [Apple's app-opening guidance](https://support.apple.com/en-us/102445) explains its per-app approval flow.

If a recipient reports an error, distinguish “disk image cannot be opened” from “application is damaged/unverified”; report the exact text, macOS version and CPU architecture. Compare the received file's SHA-256 against the release checksum before diagnosing an incomplete transfer.
