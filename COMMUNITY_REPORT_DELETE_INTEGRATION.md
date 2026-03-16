# Community Report Delete Integration

This document describes the backend contract required for deleting community
reports from the frontend.

## Summary
- Feature: Delete a user’s community report.
- Affects screens: `MyReportsScreen`, `ReportDetailsScreen`.
- Auth: Bearer token (same as existing community report endpoints).

## Required Endpoint
```
DELETE /report/{reportId}
```

### Request
Headers:
```
Authorization: Bearer <token>
Content-Type: application/json
```

Path params:
- `reportId` (int, required): The report id to delete.

Body:
- None (preferred).

### Successful Response
Status: `200 OK` or `204 No Content`

Example (200):
```json
{
  "success": true,
  "message": "Report deleted"
}
```

### Error Responses
- `401 Unauthorized` → session invalid/expired
- `404 Not Found` → report id not found
- `4xx/5xx` → generic failure

Example (404):
```json
{
  "success": false,
  "message": "Report not found"
}
```

## Frontend Implementation Notes
- Service method added: `CommunityReportService.deleteReport(reportId)`.
- UI delete actions:
  - List item delete icon in `MyReportsScreen`.
  - Delete action in `ReportDetailsScreen` app bar.
- Confirmation dialog shown before delete.
- On success:
  - List view removes the item.
  - Details screen returns `true` to refresh the list.

## TODO for Backend Team
- Implement `DELETE /report/{reportId}` with authorization.
- Ensure the report belongs to the authenticated user.
- Return `200` or `204` on success, and `404` if not found.
