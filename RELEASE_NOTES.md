# Shipper App – Upcoming Release Notes

## Highlights
- **Delivery proof stability:** Re-submitting proof no longer resets completed confirmations, preventing duplicate delivery warnings.
- **Escalation workflow:** Drivers can attach supplemental proof (photos, notes, geo-tags) when a dispute is escalated without interrupting existing confirmations.
- **Evidence visibility:** Issue detail screens now display the full proof album so support teams can review every upload in one place.
- **Training cadence:** Weekly "Tại sao lại tăng doanh thu" playbook guidance is built into the Service Center with reminders and completion tracking.

## Driver Experience
- Delivery proof modal now supports two modes:
  - Standard submissions for pending/rejected confirmations.
  - Supplemental submissions that keep the current confirmation state intact.
- Added quick action to upload extra proof even after the shop has confirmed delivery.
- Dispute cards include a "Bổ sung bằng chứng" button whenever an order is escalated or disputed.
- Driver issue cards show all uploaded proof thumbnails with tap-to-preview dialogs.

## Backend/API
- `POST /api/orders/:id/delivery-proof` accepts `supplementOnly` and `keepConfirmation` flags.
- Orders now persist a `deliveryProofAlbum` array (last 6 uploads) for auditing.
- Supplemental uploads no longer auto-reset dispute/issue states, but still broadcast socket updates.

## Enablement & Training
- Service Center home adds a weekly training reminder card with due-date logic.
- New Revenue Playbook page documents the cross-role test (Customer → Shipper → Vendor) and lets drivers mark completion, stored client-side for accountability.

## Action Items Before Deploy
1. Migrate MongoDB with the new `deliveryProofAlbum` array field (no backfill required).
2. Roll out updated shipper mobile build to QA for regression around delivery proof submissions.
3. Communicate supplemental proof workflow to vendor ops so they know extra photos may arrive without a new confirmation request.
4. Schedule the first weekly training digest using analytics from the new reminder card (optional but recommended).
