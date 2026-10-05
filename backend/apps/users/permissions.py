from rest_framework.permissions import BasePermission


class IsAdminOrTeacher(BasePermission):
    message = "Only administrators and teachers can perform this action."

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.role in {"owner", "admin", "teacher"}
        )


class IsAdmin(BasePermission):
    message = "Only owners or administrators can perform this action."

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.role in {"owner", "admin"}
        )


class IsOwner(BasePermission):
    message = "Only the owner can perform this action."

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.role == "owner"
            and request.user.is_superuser
        )
