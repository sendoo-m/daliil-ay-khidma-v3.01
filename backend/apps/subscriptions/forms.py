import re

from django import forms

from .models import SubscriptionPlan


class SubscriptionPlanForm(forms.ModelForm):
    """Form used by the custom dashboard to maintain subscription plans."""

    class Meta:
        model = SubscriptionPlan
        fields = (
            'name',
            'display_name_en',
            'display_name_ar',
            'description_en',
            'description_ar',
            'price_monthly',
            'price_quarterly',
            'price_semi_annual',
            'price_annual',
            'max_products',
            'max_images_per_product',
            'max_business_images',
            'can_upload_images',
            'can_show_prices',
            'has_delivery_options',
            'has_analytics',
            'featured_in_search',
            'can_create_deals',
            'has_social_media_links',
            'has_verified_badge',
            'color',
            'icon',
            'order',
            'is_active',
            'is_popular',
        )
        widgets = {
            'name': forms.Select(attrs={'class': 'form-select'}),
            'display_name_en': forms.TextInput(attrs={'class': 'form-control', 'dir': 'ltr'}),
            'display_name_ar': forms.TextInput(attrs={'class': 'form-control', 'dir': 'rtl'}),
            'description_en': forms.Textarea(attrs={'class': 'form-control', 'rows': 4, 'dir': 'ltr'}),
            'description_ar': forms.Textarea(attrs={'class': 'form-control', 'rows': 4, 'dir': 'rtl'}),
            'price_monthly': forms.NumberInput(attrs={'class': 'form-control', 'min': '0', 'step': '0.01'}),
            'price_quarterly': forms.NumberInput(attrs={'class': 'form-control', 'min': '0', 'step': '0.01'}),
            'price_semi_annual': forms.NumberInput(attrs={'class': 'form-control', 'min': '0', 'step': '0.01'}),
            'price_annual': forms.NumberInput(attrs={'class': 'form-control', 'min': '0', 'step': '0.01'}),
            'max_products': forms.NumberInput(attrs={'class': 'form-control', 'min': '0'}),
            'max_images_per_product': forms.NumberInput(attrs={'class': 'form-control', 'min': '0'}),
            'max_business_images': forms.NumberInput(attrs={'class': 'form-control', 'min': '0'}),
            'color': forms.TextInput(attrs={'class': 'form-control form-control-color', 'type': 'color'}),
            'icon': forms.TextInput(attrs={'class': 'form-control', 'dir': 'ltr', 'placeholder': 'fas fa-tag'}),
            'order': forms.NumberInput(attrs={'class': 'form-control'}),
        }

    def clean_color(self):
        color = (self.cleaned_data.get('color') or '').strip()
        if not re.fullmatch(r'#[0-9a-fA-F]{6}', color):
            raise forms.ValidationError('Enter a valid HEX color such as #667eea.')
        return color
