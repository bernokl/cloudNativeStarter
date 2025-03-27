{ lib, values, config, ... }: {

  resources.services.dummy-service = {
    metadata.labels.app = "dummy-service";
    spec = {
      ports.http = {
        protocol = "TCP";
        port = 80;
        targetPort = "http";
      };
      selector.app = "dummy-service";
    };
  };

}
