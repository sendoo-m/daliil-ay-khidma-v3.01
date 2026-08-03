# apps/dashboard/forms/review.py
from django import forms
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Submit

from apps.reviews.models import ReviewReply


class ReviewReplyForm(forms.ModelForm):
    """فورم رد صاحب المحل على التقييم"""
    
    class Meta:
        model = ReviewReply  # ← ReviewReply مش Review
        fields = ['comment']
        widgets = {
            'comment': forms.Textarea(attrs={
                'rows': 3,
                'placeholder': 'اكتب ردك على التقييم...',
                'class': 'form-control',
            }),
        }
        labels = {
            'comment': 'الرد',
        }
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_method = 'post'
        self.helper.layout = Layout(
            'comment',
            Submit('submit', 'إرسال الرد', css_class='btn btn-success'),
        )
