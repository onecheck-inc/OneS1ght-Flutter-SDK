# ones1ght_sdk example

Buttons for each step: initialize → permission → first floor → begin / end. SDK logs and events are listed below.

```sh
flutter run --dart-define=ONES1GHT_SDK_KEY=ock_sdk_…
```

Integration tests run without a key and check that calls reach the native SDK:

```sh
flutter test integration_test -d <device>
```
