/**
 * Main JavaScript - Daliil Ay Khidma
 */

$(document).ready(function() {

    // ==========================================
    // Back to Top Button
    // ==========================================
    $(window).on('scroll', function() {
        if ($(this).scrollTop() > 120) {
            $('#backToTop').fadeIn();
        } else {
            $('#backToTop').fadeOut();
        }
    });

    $('#backToTop').on('click', function() {
        $('html, body').animate({ scrollTop: 0 }, 650);
        return false;
    });

    // ==========================================
    // Auto-hide Alerts
    // ==========================================
    setTimeout(function() {
        $('.alert').fadeOut('slow');
    }, 4500);

    // ==========================================
    // Navbar Scroll Effect
    // ==========================================
    $(window).on('scroll', function() {
        if ($(this).scrollTop() > 30) {
            $('.navbar').addClass('navbar-scrolled shadow-sm');
        } else {
            $('.navbar').removeClass('navbar-scrolled shadow-sm');
        }
    });

    // ==========================================
    // Smooth Scroll for Anchor Links
    // ==========================================
    $('a[href^="#"]').on('click', function(e) {
        const target = $(this.hash);
        if (target.length) {
            e.preventDefault();
            $('html, body').animate({
                scrollTop: target.offset().top - 80
            }, 650);
        }
    });

    // ==========================================
    // Form Validation Feedback (FIXED)
    // ==========================================
    $('form').on('submit', function(event) {
        const form = $(this);
        if (form[0].checkValidity() === false) {
            event.preventDefault();
            event.stopPropagation();
        }
        form.addClass('was-validated');
    });

    // ==========================================
    // Tooltips Initialization
    // ==========================================
    const tooltipTriggerList = [].slice.call(
        document.querySelectorAll('[data-bs-toggle="tooltip"]')
    );
    tooltipTriggerList.map(function(el) {
        return new bootstrap.Tooltip(el);
    });

    // ==========================================
    // Popovers Initialization
    // ==========================================
    const popoverTriggerList = [].slice.call(
        document.querySelectorAll('[data-bs-toggle="popover"]')
    );
    popoverTriggerList.map(function(el) {
        return new bootstrap.Popover(el);
    });

    // ==========================================
    // AJAX CSRF Token Setup
    // ==========================================
    function getCookie(name) {
        let cookieValue = null;
        if (document.cookie && document.cookie !== '') {
            const cookies = document.cookie.split(';');
            for (let i = 0; i < cookies.length; i++) {
                const cookie = cookies[i].trim();
                if (cookie.substring(0, name.length + 1) === (name + '=')) {
                    cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                    break;
                }
            }
        }
        return cookieValue;
    }

    const csrftoken = getCookie('csrftoken');
    $.ajaxSetup({
        beforeSend: function(xhr, settings) {
            if (!(/^(GET|HEAD|OPTIONS|TRACE)$/i.test(settings.type)) && !this.crossDomain) {
                xhr.setRequestHeader("X-CSRFToken", csrftoken);
            }
        }
    });

    // ==========================================
    // Search Modal Auto-focus
    // ==========================================
    $('#searchModal').on('shown.bs.modal', function() {
        $('#searchModal input[name="q"]').trigger('focus');
    });

    // ==========================================
    // Leaflet Map: RTL Visibility Fix (GLOBAL HELPER)
    // - Call window.fixLeafletMap(mapInstance) after you create a Leaflet map.
    // - Also works when map is inside tabs/collapses.
    // ==========================================
    window.fixLeafletMap = function(map) {
        if (!map) return;

        // Invalidate size twice to be safe (tabs/layout shift)
        setTimeout(() => map.invalidateSize(), 50);
        setTimeout(() => map.invalidateSize(), 250);

        // Keep after resize too
        window.addEventListener('resize', () => map.invalidateSize());
    };

    // If you use Bootstrap tabs and map inside a tab
    document.querySelectorAll('[data-bs-toggle="tab"]').forEach((tabEl) => {
        tabEl.addEventListener('shown.bs.tab', () => {
            // If you store your map on window.businessMap, it will be refreshed automatically
            if (window.businessMap) window.fixLeafletMap(window.businessMap);
        });
    });

    // ==========================================
    // Console Branding
    // ==========================================
    console.log('%c Daliil Ay Khidma ',
        'background: #4f46e5; color: white; font-size: 18px; padding: 8px 12px; border-radius: 10px;'
    );
    console.log('%c Made with ❤️ in Egypt ',
        'background: #2563eb; color: white; font-size: 13px; padding: 6px 10px; border-radius: 10px;'
    );
});


// Leaflet maps inside tabs fix (global)
document.addEventListener('shown.bs.tab', function () {
  if (window.L && typeof window.L === 'object') {
    setTimeout(() => {
      document.querySelectorAll('.leaflet-container').forEach(el => {
        // find map instance is not straightforward; we already handle invalidateSize in page script
      });
    }, 120);
  }
});
