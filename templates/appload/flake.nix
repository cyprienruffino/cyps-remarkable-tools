{
  inputs.remarkable-sdk.url = "github:cyprienruffino/remarkable-sdk";

  outputs = { remarkable-sdk, ... }: {
    devShells = remarkable-sdk.devShells;
  };
}
