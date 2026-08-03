"""
Fix Deal Slugs Management Command
==================================
تنظيف وإصلاح slugs للعروض
"""

from django.core.management.base import BaseCommand
from django.utils.text import slugify
from apps.deals.models import Deal
import re


class Command(BaseCommand):
    help = 'Fix invalid slugs in deals'
    
    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be changed without making changes',
        )
    
    def handle(self, *args, **options):
        dry_run = options['dry_run']
        
        if dry_run:
            self.stdout.write(self.style.WARNING('DRY RUN MODE - No changes will be made\n'))
        
        deals = Deal.objects.all()
        fixed_count = 0
        error_count = 0
        
        self.stdout.write(f'Found {deals.count()} deal(s) to check...\n')
        
        for deal in deals:
            old_slug = deal.slug
            
            try:
                # Force regenerate slug
                deal.slug = ''
                new_slug = deal._generate_unique_slug()
                
                # Check if slug needs fixing
                if old_slug != new_slug:
                    if not dry_run:
                        deal.slug = new_slug
                        deal.save(update_fields=['slug'])
                    
                    self.stdout.write(
                        self.style.SUCCESS(
                            f'✓ {"[DRY RUN] " if dry_run else ""}Fixed: "{old_slug}" → "{new_slug}"'
                        )
                    )
                    fixed_count += 1
                else:
                    self.stdout.write(
                        self.style.WARNING(f'  Skipped (already valid): "{old_slug}"')
                    )
            
            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(f'✗ Error fixing "{old_slug}": {str(e)}')
                )
                error_count += 1
        
        # Summary
        self.stdout.write('\n' + '='*50)
        if fixed_count > 0:
            status = 'Would fix' if dry_run else 'Fixed'
            self.stdout.write(
                self.style.SUCCESS(
                    f'🎉 {status} {fixed_count} deal slug(s)!'
                )
            )
        else:
            self.stdout.write(
                self.style.WARNING('No slugs needed fixing.')
            )
        
        if error_count > 0:
            self.stdout.write(
                self.style.ERROR(f'❌ {error_count} error(s) occurred.')
            )
        
        if dry_run:
            self.stdout.write(
                self.style.WARNING('\nRun without --dry-run to apply changes')
            )
