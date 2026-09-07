# v22 signing verification fix

The v21 run showed `apksigner` output contained `Number of signers: 1`, but the anchored `sed` parser still returned empty. v22 replaces that parser with a Bash regex scan over the captured output, tolerating CRLF and surrounding/preceding formatting while extracting the signer count. No signing configuration or application code was changed.
