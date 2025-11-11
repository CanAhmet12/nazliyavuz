# API Endpoints Summary

This document provides a comprehensive overview of all available API endpoints.

## Authentication

- `POST /auth/register` - Register new user
- `POST /auth/login` - User login
- `POST /auth/logout` - User logout
- `POST /auth/refresh` - Refresh token
- `POST /auth/forgot-password` - Request password reset
- `POST /auth/reset-password` - Reset password

## Social Authentication

- `POST /auth/social/google` - Google OAuth login
- `POST /auth/social/facebook` - Facebook OAuth login
- `POST /auth/social/apple` - Apple Sign-In
- `GET /auth/social/accounts` - Get linked social accounts
- `DELETE /auth/social/accounts/{provider}` - Disconnect social account

## Teachers

- `GET /teachers` - Get all teachers with filters
- `GET /teachers/{teacher}` - Get single teacher
- `POST /teachers` - Create teacher profile
- `PUT /teachers/{teacher}` - Update teacher profile
- `DELETE /teachers/{teacher}` - Delete teacher profile

## Search

- `GET /search` - Search teachers
- `GET /search/suggestions` - Get search suggestions
- `GET /search/trending` - Get trending teachers
- `GET /search/filters` - Get available filters

## Reservations

- `GET /reservations` - Get user reservations
- `POST /reservations` - Create reservation
- `PUT /reservations/{reservation}/status` - Update reservation status
- `DELETE /reservations/{reservation}` - Cancel reservation

## Chat

- `GET /chat/conversations` - Get conversations
- `GET /chat/conversations/{conversation}/messages` - Get messages
- `POST /chat/messages` - Send message
- `PUT /chat/messages/{message}/read` - Mark message as read

## Admin

- `GET /admin/dashboard` - Get admin dashboard
- `GET /admin/users` - Get users list
- `GET /admin/analytics` - Get platform analytics
- `GET /admin/system-health` - Get system health status

## Notifications (Authenticated Users)

- `POST /notifications/register-token` - Register device token for push notifications
- `POST /notifications/unregister-token` - Remove device token
- `POST /notifications/test` - Trigger a self test notification
- `GET /notifications/settings` - Fetch channel preferences (email / sms / push)
- `PUT /notifications/settings` - Update channel preferences

## Admin Notifications & Templates

- `POST /admin/notifications/send` - Send immediate notification (single or segment)
- `POST /admin/notifications/bulk` - Dispatch bulk notifications
- `POST /admin/notifications/user` - Send notification to a specific user
- `POST /admin/notifications/mark-read` - Mark notifications as read
- `GET /admin/notifications` - List recently sent notifications
- `GET /admin/notifications/stats` - Notification success / failure KPIs
- `GET /admin/notifications/analytics` - Channel-based analytics
- `DELETE /admin/notifications/cleanup` - Purge expired notification logs

### Scheduled Notifications

- `GET /admin/notifications/scheduled` - List scheduled notification jobs
- `POST /admin/notifications/scheduled` - Create scheduled notification
- `PUT /admin/notifications/scheduled/{id}` - Update scheduled notification
- `POST /admin/notifications/scheduled/{id}/schedule` - Reschedule upcoming run
- `POST /admin/notifications/scheduled/{id}/send-now` - Execute immediately
- `POST /admin/notifications/scheduled/{id}/cancel` - Cancel scheduled job
- `GET /admin/notifications/scheduled/{id}/logs` - Retrieve execution history

### Notification Templates

- `GET /admin/notification-templates` - List templates
- `GET /admin/notification-templates/{template}` - Fetch template detail
- `POST /admin/notification-templates` - Create template
- `PUT /admin/notification-templates/{template}` - Update template
- `POST /admin/notification-templates/{template}/publish` - Publish template
- `POST /admin/notification-templates/{template}/archive` - Archive template
- `POST /admin/notification-templates/{template}/duplicate` - Duplicate template
- `POST /admin/notification-templates/{template}/render` - Render with sample payload
- `POST /admin/notification-templates/{template}/test-send` - Send test notification using env credentials
- `GET /admin/notification-templates/variables` - List available placeholder variables

