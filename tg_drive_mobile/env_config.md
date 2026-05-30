# Environment Configuration

API credentials are passed at build time via `--dart-define`:

```sh
flutter build apk --debug \
  --dart-define=API_ID=your_api_id \
  --dart-define=API_HASH=your_api_hash
```

For `flutter run`:
```sh
flutter run \
  --dart-define=API_ID=your_api_id \
  --dart-define=API_HASH=your_api_hash
```

Get credentials at https://my.telegram.org/apps
