# Project merge note

This project was assembled as requested:

- Base project and all unrelated features: `GrapheneSquare_cooker_app-master (7)`
- Community feature: `GrapheneSquare_cooker_app_admin_notice_report_popularity`
- My Page feature except the actual app-settings subpage: `GrapheneSquare_cooker_app_admin_notice_report_popularity`
- App-settings subpage (`/settings/app`): `GrapheneSquare_cooker_app-master (7)`
- Pet feature/assets and `/pet-test`: retained from `master (7)`

The selected community/My Page implementation depends on account-scoped local API tokens,
personal recipes, cooking history, and profile providers. The minimum related auth/network/recipe
support files and the local FastAPI `main.py` were therefore retained from the admin project.

## Local files to preserve when replacing an existing project

Do not overwrite or delete these existing runtime files:

- `.env`
- `multicooker.db`
- `local_uploads/`

The uploaded `.env 2` file was intentionally excluded from this distributable archive. Use `.env.example`
as a template or keep the existing `.env` in the local working directory.
