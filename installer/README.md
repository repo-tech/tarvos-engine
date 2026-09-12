# Tarvos Windows installer

`Tarvos.iss` builds the user-local Windows setup executable:

```text
Tarvos-Setup-Windows-x86_64.exe
```

The installer is designed like a normal developer-tool setup wizard:

- blue Tarvos branding;
- no administrator prompt (`PrivilegesRequired=lowest`);
- installation under the current user's profile;
- current-user `PATH` registration;
- clean uninstall support;
- no compiler source bundled.

The release pipeline supplies the compiled `payload\tarvos.exe` before
invoking Inno Setup. The public repository intentionally does not store that
binary.
