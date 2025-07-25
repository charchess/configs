{ config, pkgs, ... }:

{

  security.sudo = {
    enable = true;
    extraRules = [{
      users = [ "issarlk" "charchess" ];
      commands = [{
          command = "ALL";
          options = [ "NOPASSWD" ];
      }];
    }];
  };

  users.users = {
    charchess = {
      isNormalUser = true;
      description = "charchess";
      extraGroups = [ "networkmanager" "wheel" ];
      packages = with pkgs; [];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdMpROENhrrWxRiXt38zNZt3iU25kCDDnrNOFNL+XAv7xymLQGLL3tnLGksku1+zaQeEkMXi+36Rpl9ql0fe6RYVpa53bOTD571lp6be+tXkF5wXuL36RDq2zx5088BS9PFyyGkgocIX9PXmT7JI1Cc3udVy8Uj3gLkODRyggNK2oHRUi6B7UNrYs4y5QnfpE/FqAw2XiJgmuBnvYA1eEnah8qv2fflYdvquk4okkM+3Ed8Za5KnUzJOasF1L/fkgaqmxH4aruI0L3K7biemcl9VNEt2GDxDvh9W8YwdRq6jiVKPKlEtHfQTamu0eskI9DqKka/gd5r4FpXtxh2/m2pdifAXAMHbz6sFeQvyPeQsa/EbPfC6e6lRRqYAJXQdB5ZcJ1MOncO15wJ58LDPpf2zovVmppIjLXNi/3F+cDR8Q7EZjrPa/P3K09jW824TaPD76ByWb8Fpx0S9clwca7W0xnj/CmtNRIL+aipOJ80zqtgQUsHEmlWKB52JvcapyTKMde80x2V4PbJZXlEyRreFLnVF9stOquMTZw7AG4elRCQGWhHz1/rd6fpNhLzm0ATXC3PFvPBNFuYRO3dbkE/8oaJoK3v7AtHYW5p3sBx2mxfvkQZGKTR57pDG4wGzSYPm0VleXhWLVsIQNXQ8oPRT7PP3lEqg6KuxPTKTH3Yw== charchess@truxonline-homelab"
      ];
    };

    issarlk = {
      isNormalUser = true;
      description = "charchess";
      extraGroups = [ "networkmanager" "wheel" ];
      packages = with pkgs; [];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEArTflMdTi+WGL0qptp5bJWnRBx54nOMmvYx8G66gigpjnjKqKV2c7NVf/wIo8G6pWzdj4XAOwnjUSERran5cJbpj/SqD0ah9Fr2xYZ7HcvmqasXejnrizRGdfIjCJPLTP8C77wrZ5a13+H4Rg3MN+B8E9i5/wsMvgwgkz6jagkIk8RFyQbs/8iULVdhYnNiosNYkFDA8c9AzoThS1EwOT0namQBU/T1t1IMbqxXJSv1cY9k01hMW6sdytl9XmQu9mk6FDlxQKwYTpbKzxo/cRE2ez3nhSKo5cAL3NAciQbDLQKgTDnnNMpT1oZbHOdNFsdnAwrmrPl4kwLCEeK+2UjQ=="
      ];
    };

    root = {
      openssh.authorizedKeys.keys =  lib.mkForce [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdMpROENhrrWxRiXt38zNZt3iU25kCDDnrNOFNL+XAv7xymLQGLL3tnLGksku1+zaQeEkMXi+36Rpl9ql0fe6RYVpa53bOTD571lp6be+tXkF5wXuL36RDq2zx5088BS9PFyyGkgocIX9PXmT7JI1Cc3udVy8Uj3gLkODRyggNK2oHRUi6B7UNrYs4y5QnfpE/FqAw2XiJgmuBnvYA1eEnah8qv2fflYdvquk4okkM+3Ed8Za5KnUzJOasF1L/fkgaqmxH4aruI0L3K7biemcl9VNEt2GDxDvh9W8YwdRq6jiVKPKlEtHfQTamu0eskI9DqKka/gd5r4FpXtxh2/m2pdifAXAMHbz6sFeQvyPeQsa/EbPfC6e6lRRqYAJXQdB5ZcJ1MOncO15wJ58LDPpf2zovVmppIjLXNi/3F+cDR8Q7EZjrPa/P3K09jW824TaPD76ByWb8Fpx0S9clwca7W0xnj/CmtNRIL+aipOJ80zqtgQUsHEmlWKB52JvcapyTKMde80x2V4PbJZXlEyRreFLnVF9stOquMTZw7AG4elRCQGWhHz1/rd6fpNhLzm0ATXC3PFvPBNFuYRO3dbkE/8oaJoK3v7AtHYW5p3sBx2mxfvkQZGKTR57pDG4wGzSYPm0VleXhWLVsIQNXQ8oPRT7PP3lEqg6KuxPTKTH3Yw== charchess@truxonline-homelab"
      ];
    };

  };
}
