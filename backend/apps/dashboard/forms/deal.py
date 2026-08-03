"""
Deal Form
"""

from django import forms
from apps.deals.models import Deal
from apps.directory.models import Business


class DealForm(forms.ModelForm):
    """Deal Creation/Update Form"""
    
    def __init__(self, *args, **kwargs):
        self.user = kwargs.pop('user', None)
        super().__init__(*args, **kwargs)
        
        # Limit business choices to user's businesses
        if self.user:
            self.fields['business'].queryset = Business.objects.filter(owner=self.user)
    
    class Meta:
        model = Deal
        fields = [
            'business',
            'deal_type',
            'title_en', 'title_ar',
            'description_en', 'description_ar',
            'discount_percentage', 'discount_amount',
            'original_price', 'final_price',
            'start_date', 'end_date',
            'terms_en', 'terms_ar',
            'is_featured',
        ]
        
        widgets = {
            'business': forms.Select(attrs={
                'class': 'form-select'
            }),
            'deal_type': forms.Select(attrs={
                'class': 'form-select'
            }),
            'title_en': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Deal title in English'
            }),
            'title_ar': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'عنوان العرض',
                'dir': 'rtl'
            }),
            'description_en': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 4,
                'placeholder': 'Deal description'
            }),
            'description_ar': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 4,
                'placeholder': 'وصف العرض',
                'dir': 'rtl'
            }),
            'discount_percentage': forms.NumberInput(attrs={
                'class': 'form-control',
                'step': '0.01',
                'min': '0',
                'max': '100'
            }),
            'discount_amount': forms.NumberInput(attrs={
                'class': 'form-control',
                'step': '0.01',
                'min': '0'
            }),
            'original_price': forms.NumberInput(attrs={
                'class': 'form-control',
                'step': '0.01',
                'min': '0'
            }),
            'final_price': forms.NumberInput(attrs={
                'class': 'form-control',
                'step': '0.01',
                'min': '0'
            }),
            'start_date': forms.DateTimeInput(attrs={
                'class': 'form-control',
                'type': 'datetime-local'
            }),
            'end_date': forms.DateTimeInput(attrs={
                'class': 'form-control',
                'type': 'datetime-local'
            }),
            'terms_en': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 3,
                'placeholder': 'Terms and conditions'
            }),
            'terms_ar': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 3,
                'placeholder': 'الشروط والأحكام',
                'dir': 'rtl'
            }),
            'is_featured': forms.CheckboxInput(attrs={
                'class': 'form-check-input'
            }),
        }
        
        labels = {
            'business': 'المحل',
            'deal_type': 'نوع العرض',
            'title_en': 'Title (English)',
            'title_ar': 'عنوان العرض',
            'description_en': 'Description (English)',
            'description_ar': 'الوصف',
            'discount_percentage': 'نسبة الخصم %',
            'discount_amount': 'قيمة الخصم',
            'original_price': 'السعر الأصلي',
            'final_price': 'السعر النهائي',
            'start_date': 'تاريخ البداية',
            'end_date': 'تاريخ النهاية',
            'terms_en': 'Terms (English)',
            'terms_ar': 'الشروط',
            'is_featured': 'عرض مميز',
        }
