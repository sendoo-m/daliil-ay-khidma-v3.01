from django.contrib import admin
from .models import Review, ReviewLike, ReviewReply, ReviewReport


admin.site.register(Review)
admin.site.register(ReviewReply)
admin.site.register(ReviewLike)
admin.site.register(ReviewReport)
