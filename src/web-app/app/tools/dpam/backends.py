from app.tools.dpam import pam

from django.conf import settings
from django.contrib.auth.models import User

class PAMBackend:
    def authenticate(self, username=None, password=None):

        service = getattr(settings, 'PAM_SERVICE', 'login')
        if not pam.authenticate(username, password, service=service):
            return None

        try:
            user = User.objects.get(username=username)
        except:
            if not getattr(settings, "PAM_CREATE_USER", True):
                return None
            user = User(username=username, password='not stored here')
            user.set_unusable_password()

            if getattr(settings, 'PAM_IS_SUPERUSER', False):
              user.is_superuser = True

            if getattr(settings, 'PAM_IS_STAFF', user.is_superuser):
              user.is_staff = True

            user.save()
        return user

    def get_user(self, user_id):
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None
