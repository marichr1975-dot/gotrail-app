# GoTr-Ail V11.7 iOS

Copia iOS della V11.7 stabile/congelata.

Modifiche specifiche iOS:
- `Info.plist` ripulito e corretto.
- permessi posizione e fotocamera aggiunti.
- deployment target iOS 13.0.
- aggiunto `Podfile` per CocoaPods.
- rimossa la dipendenza diretta Android-only `camera_android` dal `pubspec.yaml`.
- la logica/app V11.7 resta invariata.

La build GitHub Actions viene prodotta **senza firma Apple** (`--no-codesign`) e impacchettata come IPA per successiva firma/installazione con Sideloadly.
