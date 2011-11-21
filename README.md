myGengo Perl Library (for the [myGengo API](http://mygengo.com/api/))
========================================================================================================
Translating your tools and products helps people all over the world access them; this is, of course, a
somewhat tricky problem to solve. **[myGengo](http://mygengo.com/)** is a service that offers human-translation
(which is often a higher quality than machine translation), and an API to manage sending in work and watching
jobs. This is a Perl interface to make using the API simpler. 

Installation & Requirements
-------------------------------------------------------------------------------------------------------
This module is not on CPAN yet; to use it, simply include it in your project, then...

``` perl
use MyGengo;
```

To use this module, you'll also need to make sure you have the `JSON` and `LWP` packages installed from CPAN.


Question, Comments, Complaints?
------------------------------------------------------------------------------------------------------
If you have questions or comments and would like to reach us directly, please feel free to do
so at the following outlets. We love hearing from developers!

Email: ryan [at] mygengo dot com  
Twitter: **[@mygengo_dev](http://twitter.com/mygengo_dev)**  

If you come across any issues, please file them on the **[Github project issue tracker](https://github.com/myGengo/mygengo-perl-new/issues)**. Thanks!


Documentation
-----------------------------------------------------------------------------------------------------
**Full documentation of each function is below**, but anyone should be able to cobble together 
a working script with the following:

``` perl
#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use MyGengo;

# Get an instance of a mygengo client
my $mygengo = MyGengo->new('api public key', 'api private key', 'sandbox_true_or_false');

# Retrieve basic account information...
my $stats = $mygengo->getAccountStats();
my $balance = $mygengo->getAccountBalance();

# Post a job to myGengo
my $job = $mygengo->postTranslationJob({
    type => 'text',
    slug => 'Test',
    body_src => 'HEY ITSA ME A PERL LIBRARIO',
    lc_src => 'en',
    lc_tgt => 'ja',
    tier => 'standard'
});

# Check the response, etc.
print $job->{'response'};
```

This should be enough to get anyone started; the library is very well documented, and each
function should have accompanying comments and Perldocs if you take a quick read through!
