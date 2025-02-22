# @rnx-kit/metro-plugin-typescript

## 0.3.3

### Patch Changes

- 75b98095: Disable the plugin if the current Metro version is unsupported
- Updated dependencies [75b98095]
  - @rnx-kit/tools-react-native@1.3.0

## 0.3.2

### Patch Changes

- 6a63f437: Fix failure to typecheck when running on Windows

## 0.3.1

### Patch Changes

- 95a35126: Lower Node version requirement to support any 14 LTS
- Updated dependencies [15baa5d5]
  - @rnx-kit/config@0.6.1

## 0.3.0

### Minor Changes

- d8d0cf37: Support new `plugins` option in CLI

### Patch Changes

- Updated dependencies [d8d0cf37]
  - @rnx-kit/config@0.6.0

## 0.2.0

### Minor Changes

- f01bdef6: Add a new TypeScript module resolver for React Native projects which uses the
  `moduleSuffixes` compiler option. All resolution is delegated to TypeScript,
  rather than @rnx-kit/typescript-react-native-resolver, since TypeScript's
  resolvers are more feature-rich and in sync with the node ecosystem.

### Patch Changes

- Updated dependencies [f01bdef6]
  - @rnx-kit/typescript-react-native-resolver@0.3.1

## 0.1.0

### Minor Changes

- 2f0c782e: Extract TypeScript plugin from `@rnx-kit/cli`
