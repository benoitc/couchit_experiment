(function($) {
    $.couchit = $.couchit || {};

    function CreateSite(app) {
        var self = this;
        
        var old_value = "",
            cname_focus = false,
            started_creation = false;


        this.validCname = function() {
            var v = $("#cname").val();
            if (old_value != v)
                if (v.length > 3 && !v.match(/^(\w+)$/)) {
                    $(".cname_row span.help").html("Site name invalid.").removeClass("hidden");
                    $(".cname_row").addClass("error");
                } else if (v.length <= 3 && cname_focus) {
                    $(".cname_row span.help").html("Length must be > 3.").removeClass("hidden");
                    $(".cname_row").addClass("error");

                } else {
                    $(".cname_row span.help").html("").addClass("hidden");
                    $(".cname_row").removeClass("error");
                }
            old_value = v;
            setTimeout(function() {
                self.validCname();
            }, 200);
        }

        this.redirectToSite = function(cname) {
            document.location = "http://"+ cname + "." + settings.hostname;
        };

        this.waitCreation = function(cname) {
            if (!started_creation) {
                $("#fcreate").addClass("hidden");
                $("#wait-creation").removeClass("hidden");
                started_creation = true;
            }

            $.ajax({
                type: "GET",
                url: "http://"+ cname + "." + settings.hostname,
                async: false,
                success: function() {
                    self.redirectToSite(cname);
                },
                error: function() {
                    console.log("error loop");
                    setTimeout(function() {
                        return self.waitCreation(cname);
                    }, 200);
                }
            });
        };   


        $("#hostname").html( settings.hostname);

        $("#cname").focus(function() {
            cname_focus = true;
        });

        $("#fcreate").submit(function(e) {
            e.preventDefault();

            $(".error span").html("").addClass("hidden");
            $(".error").removeClass("error");

            var nb_error=0;
            var cname = $("#cname").val(),
                guest_password = $("#guestpwd").val() || "",
                can_write = $("#canwrite").val() ||0,
                can_upload = $("#canupload").val() || 0,
                can_delete = $("#candelete").val() || 0;

            if (cname.length <= 3 || !cname.match(/^(\w+)$/)) {
                $(".cname_row span.help").html("CouchDB url invalid.").removeClass("hidden");
                $(".cname_row").addClass("error");
                nb_error += 1;
            }

            if (nb_error == 0) {
                 var site = {
                    name: cname,
                    guest_password: guest_password,
                    can_write: can_write,
                    can_upload: can_upload,
                    can_delete: can_delete
                };

                $.ajax({
                    type: "POST",
                    url: "/_site",
                    async: false,
                    contentType: "application/json", 
                    dataType: "json",
                    data: JSON.stringify(site),

                    success: function() {
                        self.waitCreation(cname); 
                    }
                });
            
            }
            return false;
        });

        
        $(".additional").bind("click", function(e) {
            e.preventDefault();
            if ($(this).hasClass("fewer")) {
                $("#options").addClass("hidden");
                $(this)
                    .html("+ Additional options (password, permissions)")
                    .removeClass("fewer");
            } else {
                $("#options").removeClass("hidden");
                $(this)
                    .html("- Fewer options (password, permissions)")
                    .addClass("fewer");
            }
            return false;
        });
         

        this.validCname();
    }

    $.extend($.couchit, {
        CreateSite: CreateSite
    });

})(jQuery);
