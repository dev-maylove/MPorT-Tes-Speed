# Keystore — MPorT Tes Speed

## File yang disertakan

| File | Lokasi | Keterangan |
|------|--------|------------|
| `mport-release-key.jks` | `android/app/` | Keystore release |
| `key.properties` | `android/` | Kredensial (JANGAN commit ke public repo) |

## Kredensial (untuk testing / internal)

```
Alias      : mport
Store pass : mport123456
Key pass   : mport123456
Validity   : 10000 hari (~27 tahun)
Algorithm  : RSA 2048
```

**PENTING:**  
Ganti password dan buat keystore baru sebelum publish ke Play Store / distribusi publik.  
Jangan commit `key.properties` dan `*.jks` ke repository publik.

## Cara pakai di CI (GitHub Actions)

Simpan sebagai GitHub Secrets:

- `KEYSTORE_BASE64` → base64 dari file `.jks`
- `KEYSTORE_PASSWORD`
- `KEY_PASSWORD`
- `KEY_ALIAS`

Contoh step di workflow:

```yaml
- name: Decode keystore
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/app/mport-release-key.jks

- name: Create key.properties
  run: |
    cat > android/key.properties << EOF
    storePassword=${{ secrets.KEYSTORE_PASSWORD }}
    keyPassword=${{ secrets.KEY_PASSWORD }}
    keyAlias=${{ secrets.KEY_ALIAS }}
    storeFile=mport-release-key.jks
    EOF
```

## Generate keystore baru (jika perlu)

```bash
keytool -genkeypair -v \
  -keystore android/app/mport-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias mport \
  -storepass YOUR_STORE_PASS \
  -keypass YOUR_KEY_PASS \
  -dname "CN=MPorT Tes Speed, OU=HaaNSirO, O=HaaNSirO, L=Jakarta, ST=DKI Jakarta, C=ID"
```

Lalu update `android/key.properties`.
