"""Consistent error responses for web and mobile API clients."""

from rest_framework.views import exception_handler


def mobile_api_exception_handler(exc, context):
    response = exception_handler(exc, context)
    if response is None:
        return None

    detail = response.data
    message = detail.get('detail') if isinstance(detail, dict) else None
    response.data = {
        'success': False,
        'status_code': response.status_code,
        'message': str(message or 'تعذر تنفيذ الطلب'),
        'errors': detail,
    }
    return response
