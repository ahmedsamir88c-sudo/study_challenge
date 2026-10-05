from getpass import getpass

from django.conf import settings
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.management.base import BaseCommand, CommandError

from apps.users.models import User


class Command(BaseCommand):
    help = "Create the configured owner account with a hidden password prompt."

    def add_arguments(self, parser):
        parser.add_argument("--full-name", default="")

    def handle(self, *args, **options):
        university_id = settings.OWNER_UNIVERSITY_ID
        if not university_id:
            raise CommandError("Set OWNER_UNIVERSITY_ID before creating the owner.")

        if User.objects.filter(university_id=university_id).exists():
            raise CommandError(
                "An account already uses this university ID. Inspect it manually; "
                "this command will not promote existing accounts."
            )
        if User.objects.filter(username__iexact=university_id).exists():
            raise CommandError(
                "An account already uses the owner ID as its username."
            )

        password = getpass("Owner password (input hidden): ")
        password_confirm = getpass("Confirm owner password (input hidden): ")
        if not password or password != password_confirm:
            raise CommandError("The passwords are empty or do not match.")

        owner = User(
            username=university_id,
            university_id=university_id,
            full_name=options["full_name"].strip(),
            role=User.Role.OWNER,
            is_staff=True,
            is_superuser=True,
        )
        try:
            validate_password(password, user=owner)
        except ValidationError as error:
            raise CommandError(" ".join(error.messages)) from error

        User.objects.create_superuser(
            username=university_id,
            password=password,
            university_id=university_id,
            full_name=owner.full_name,
            role=User.Role.OWNER,
        )
        self.stdout.write(
            self.style.SUCCESS(f"Owner account created for university ID {university_id}.")
        )