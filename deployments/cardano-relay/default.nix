{ pkgs, lib ? pkgs.lib, mkHelm, inputs }:
mkHelm {
  defaults =
    final:
    let
      inherit (final) values utils;
    in
    {
      name = "${final.namespace}-cardano-relay";
      chart = ./Chart.yaml;
      namespace = "default";

      imports = [
        ./deployment.nix
      ];

      kustomization = {
        namespace = final.namespace;
        namePrefix = "${final.namespace}-";
        commonLabels = {
          "app.kubernetes.io/name" = "cardano-relay";
          "app.kubernetes.io/component" = "cardano-stuff";
          "app.kubernetes.io/part-of" = "berno-awesome-infra";
          "app.kubernetes.io/managed-by" = "nix-toolbox";
        };
      };

      values = { };
    };

  targets = {
    prod = final: { };
  };
}
