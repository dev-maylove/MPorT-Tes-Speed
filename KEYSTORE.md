# Keystore — MPorT Tes Speed

## File

| File | Lokasi |
|------|--------|
| `mport_tes_keystore.jks` | `android/app/` (PKCS#12) |
| `key.properties` | `android/` |

## Kredensial

```
storePassword = Optionso@1212
keyPassword   = Optionso@1212
keyAlias      = mport_key_tes
storeFile     = mport_tes_keystore.jks
```

> Alias di dalam keystore: **mport_key_tes**  
> (bukan `mport_tes_keystore` — itu nama file saja)

## CI Secrets

- `KEYSTORE_BASE64` ← `base64 -w0 android/app/mport_tes_keystore.jks`
- `KEYSTORE_PASSWORD` = `Optionso@1212`
- `KEY_PASSWORD` = `Optionso@1212`
- `KEY_ALIAS` = `mport_key_tes`

## Base64 (untuk GitHub Secret)

File: `tes_keystore.txt` / `android/keystore_tes_base64.txt`

```
KEYSTORE_BASE64 = (isi file di atas, satu baris)
KEYSTORE_PASSWORD = Optionso@1212
KEY_PASSWORD = Optionso@1212
KEY_ALIAS = mport_key_tes
```
