## Historia de usuario

<!-- Referencia: HU-016 (RF-31) en code-corhuila/telemed-ia-docs#26 -->
- HU / RF:
- Issue de la HU:
- Contrato de eventos afectado:

## Qué cambia y por qué

<!-- Descripción del cambio y la razón. -->

## Cómo se probó

- [ ] CI en verde
- [ ] `liquibase update` desde base vacía
- [ ] Segundo `liquibase update` sin changesets (0 changesets)
- [ ] `rollback-count 999` ejecutado
- [ ] `liquibase update` posterior al rollback reconstruye el esquema

## Rastro de promoción

<!-- Solo para PRs hacia qa / main. Una línea por commit, con "cherry picked from commit ..." -->

```

```

## Lista de verificación

- [ ] Sin secretos ni credenciales reales en el diff
- [ ] Sin esquema de otros repositorios -db
- [ ] Contrato de eventos respetado
- [ ] PR de 400 líneas o menos
- [ ] Conventional Commit en el mensaje