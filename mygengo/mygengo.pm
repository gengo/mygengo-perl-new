package MyGengo;

use strict;
use warnings;

=head1 NAME

MyGengo.pm - Library for interacting with the myGengo API

=head1 DESCRIPTION

A Perl interface for the mygengo API. Not much to this,
should be pretty self explanatory. ;)

For reference as to what this library actually does in regards
to authentication and the like, visit the docs located in the L<SEE ALSO>
section below.

@category: myGengo

@package: API Client Library

=head1 SYNOPSIS

    use MyGengo;
    my $mygengo = MyGengo->new('pubKey', 'privKey', '1');

    # Stuff

=cut


# Necessary for our HTTP requests.
use LWP;
use URI::Escape;
use HTTP::Request;
use HTTP::Request::Common;
use JSON;

# Necessary for encoding our requests...
use URI::Escape;
use Digest::HMAC;
use Digest::SHA1;

=head1 METHODS

=head2 new( $public_api_key, $private_api_key, [$use_sandbox], [$user_agent] )

Every API caller should instantiate a new client based off this,
and then use the appropriate calls below.

Public/private API keys can be found in your account details on the myGengo
site.

If $use_sandbox is true, the sandbox will be used instead of the production
site.

If $user_agent is defined, the value will be used as the User-Agent header
for the API requests.

=cut
sub new {
    my ($class, $publicKey, $privateKey, $useSandbox, $userAgent) = @_;

    # Some HTTP-related options we wanna get out of the way...
    my $http_config = {
        'agent' => (defined($userAgent) ? $userAgent : 'myGengo Perl Library v1'),
        'max_redirect' => 5,
        'timeout' => 10
    };

    # Now we need an HTTP client to take care of dispatching things...
    my $client = LWP::UserAgent->new(\$http_config);
    $client->agent($http_config->{'agent'});
    $client->timeout($http_config->{'timeout'});

    my $json = new JSON;

    # And now we just expose it all...
    my $self = {
        publicKey => $publicKey,
        privateKey => $privateKey,
        useSandbox => $useSandbox,
        apiURL => ($useSandbox ? 'http://api.sandbox.mygengo.com/v1.1' : 'http://api.mygengo.com/v1.1'),
        client => $client,
        json => $json
    };

    bless($self, $class);
    return $self;
}

=head2 _signAndSend( $method, $endpoint, \%params )

Internal method used for POSTing/PUTing data. Left 'available'
in case anybody wants to use it for tinkering.

=cut
sub _signAndSend {
    my ($self, $method, $endpoint, $params) = @_;
    my $time = time();
    my $hmac = Digest::HMAC->new($self->{privateKey}, "Digest::SHA1");
    $hmac->add($time);

    my $datstr = 'api_sig='.$hmac->hexdigest.'&api_key='.$self->{publicKey}.'&data='.uri_escape(to_json($params)).'&ts='.$time;
    
    my $headers = HTTP::Headers->new(
        'Accept' => 'application/json; charset=utf-8',
        'Content-Type' => 'application/x-www-form-urlencoded'
    );

    my $request = HTTP::Request->new($method, $self->{apiURL}.$endpoint, $headers);
    $request->content($datstr);
    my $response = $self->{client}->request($request);

    if($response->is_success) {
        return $self->{json}->allow_nonref->utf8->relaxed->escape_slash->loose->decode($response->content);
    } else {
        # Mmmm... this'll do for now?
        return 0;
    }
}

=head2 _signAndRequest( $method, $endpoint, \%data )

Internal method used for GETting/DELETing data. Left 'available'
in case anybody wants to use it for tinkering.

=cut
sub _signAndRequest {
    my ($self, $method, $endpoint, $data) = @_;
    my $time = time();
    
    my $hmac = Digest::HMAC->new($self->{privateKey}, "Digest::SHA1");
    $hmac->add($time);

    my $url = '?ts='.$time.'&api_key='.uri_escape($self->{publicKey});
    $url .= '&api_sig='.$hmac->hexdigest;

    if ( ref($data) eq 'HASH' ) {
        foreach my $key ( keys %$data ) { 
            if ( defined($data->{$key}) ) {
                $url .= '&'."$key=".uri_escape($data->{$key}); 
            }
        }
    }
    
    my $header = HTTP::Headers->new('Accept' => 'application/json; charset=utf-8');
    my $request = HTTP::Request->new($method, $self->{apiURL}.$endpoint.$url, $header);
    my $response = $self->{client}->request($request);

    if($response->is_success) {
        return $self->{json}->allow_nonref->utf8->relaxed->escape_slash->loose->decode($response->content);
    } else {
        # Mmmm... this'll do for now?
        return 0;
    }
}

=head2 getAccountStats( )

Retrieves account stats for the authenticated account, returns it
as a Perl object and such.

=cut
sub getAccountStats {
    my ($self) = @_;
    return $self->_signAndRequest('GET', '/account/stats/');
}

=head2 getAccountBalance( )

Retrieves the balance for the authenticated account in question.

=cut
sub getAccountBalance { 
    my ($self) = @_;
    return $self->_signAndRequest('GET', '/account/balance/');
}

=head2 getTranslationJob( $id )

Retrieves a job from myGengo with the specified id.

=cut
sub getTranslationJob { 
    my ($self, $id) = @_;
    return $self->_signAndRequest('GET', '/translate/job/'.$id);
}

=head2 getTranslationJobs( [$status], [$timestamp_after], [$count] )

Acts like a filter for jobs you've previously submitted.

$status filters Jobs by status.

Valid values for $status are: "unpaid", "available", "pending", "reviewable"
, "approved", "rejected", "canceled"

$timestamp_after is an epoch timestamp. Jobs before this timestamp will not
be returned.

$count limits the number of Jobs returned. Defaults to 10 Jobs.

=cut
sub getTranslationJobs { 
    my ($self, $status, $timestamp_after, $count) = @_;
    
    return $self->_signAndRequest('GET', '/translate/jobs/', {
        status => $status,
        timestamp_after => $timestamp_after,
        count => $count
    });
}

=head2 getTranslationJobBatch( $id )

Gets a batch of jobs associated with a given job ID.

=cut
sub getTranslationJobBatch {
    my ($self, $id) = @_;
    return $self->_signAndRequest('GET', '/translate/jobs/'.$id);
}

=head2 getTranslationJobComments( $id )

Gets comments for a given Job, given the id.

=cut
sub getTranslationJobComments { 
    my ($self, $id) = @_;
    return $self->_signAndRequest('GET', '/translate/job/'.$id.'/comments');
}

=head2 getTranslationJobFeedback( $id )

Gets feedback for a given job, given the ID.

=cut
sub getTranslationJobFeedback { 
    my ($self, $id) = @_;
    return $self->_signAndRequest('GET', '/translate/job/'.$id.'/feedback');
}

=head2 getTranslationJobRevisions( $id )

Gets revisions for a given job, given the id. Revisions are created each time a translator 
or Senior Translator updates the job.

=cut
sub getTranslationJobRevisions { 
    my ($self, $id) = @_;
    return $self->_signAndRequest('GET', '/translate/job/'.$id.'/revisions');
}

=head2 getTranslationJobRevision( $id, $revision_id )

Gets a specific revision on a given job.

=cut
sub getTranslationJobRevision { 
    my ($self, $id, $revision_id) = @_;
    return $self->_signAndRequest('GET', '/translate/job/'.$id.'/revisions/'.$revision_id);
}

=head2 deleteTranslationJob( $id )

Deletes a job on the myGengo side. You can only cancel a job if it has not been
started already by a translator.

=cut
sub deleteTranslationJob { 
    my ($self, $id) = @_;
    return $self->_signAndRequest('DELETE', '/translate/job/'.$id);
}

=head2 getServiceLanguagePairs( [$source_language_code] )

Returns supported translation language pairs, tiers, and credit prices.

Optional $source_language_code is a language code of a specific source
language for which to filter.

=cut
sub getServiceLanguagePairs { 
    my ($self, $lc_src) = @_;
    
    return $self->_signAndRequest('GET', '/translate/service/language_pairs', {
        lc_src => $lc_src
    });
}

=head2 getServiceLanguages( )

Returns a list of supported languages and their language codes.

=cut
sub getServiceLanguages { 
    my ($self) = @_;
    return $self->_signAndRequest('GET', '/translate/service/languages');
}

=head2 postTranslationJob( $job )

POSTs a job to myGengo for translators to pick up and work on.

$job is a hash/object that follows our payload structure. See:

L<http://mygengo.com/api/developer-docs/payloads/> (submissions)

=cut
sub postTranslationJob {
    my ($self, $job) = @_;
    return $self->_signAndSend('POST', '/translate/job/', {job => $job});
}

=head2 postTranslationJobs( \@jobs, [$process], [$as_group] )

Post multiple jobs at once over to myGengo; accepts two extra optional parameters.
See this page for more information about this endpoint: 
L<http://mygengo.com/api/developer-docs/methods/translate-jobs-post/>

\@jobs is an array of job hashes/objects to send over.

If $process is true, the jobs should be processed/paid for immediately.

If $as_group is true, one translator will work on all these jobs together.

=cut
sub postTranslationJobs { 
    my ($self, $jobs, $process, $as_group) = @_;
    
    return $self->_signAndSend('POST', '/translate/jobs', {
        jobs => $jobs,
        process => $process,
        as_group => $as_group
    });
}

=head2 determineTranslationCost( \@jobs )

Gets an estimate for a job cost; follows the group job (postTranslationJob) method
structure, without process/as_group.

=cut
sub determineTranslationCost { 
    my ($self, $jobs) = @_;
    return $self->_signAndSend('POST', '/translate/job', $jobs);
}

=head2 updateTranslationJob( $id, \%status_obj )

Updates the given job with a few different possible statuses.

\%statusObj - A hash/object with various properties. See below...

=over

=item   "purchase" Parameters: None

=item   "revise" Parameters:
    comment: Optional. A comment describing the revision.

=item   "approve" Parameters:

    rating: Required. 1 - 5, 1 = ohgodwtfisthis, 5 = I want yo babies yo,

    for_translator: Optional. Comments that you can pass on to the translator.

    for_mygengo: Optional. Comments to send to the myGengo staff (kept private on myGengo's end)

    public: Optional. 1 (true) / 0 (false, default). Whether myGengo can share this feedback publicly.

=item   "reject" Parameters:

    reason: Required. Reason for rejection (must be "quality", "incomplete", "other")

    comment: Required. Explain your rejection, especially if all you put was "other".

    captcha: Required. The captcha image text. Each job in a "reviewable" state
        will have a captcha_url value, which is a URL to an image. This
        captcha value is required only if a job is to be rejected. If the
        captcha is wrong, a URL for a new captcha is also included with the
        error message.

    follow_up: Optional. "requeue" (default) or "cancel". If you choose
        "requeue" the job will be rejected and then passed onto another
        translator. If you choose "cancel" the job will be completely
        cancelled upon rejection.

=back

=cut
sub updateTranslationJob { 
    my ($self, $id, $statusObj) = @_;
    return $self->_signAndSend('PUT', '/translate/job/'.$id, $statusObj);
}

=head2 updateTranslationJobs( \@jobs_status_obj )

Updates multiple jobs with a few different possible statuses.

\@jobsStatusObj is an array of hashes/objects with various properties. Each
object must have a "job_id" set, as well as an action object (like the details
below).

=over

=item   "purchase" Parameters: None

=item   "revise" Parameters:

    comment: Optional. A comment describing the revision.

=item   "approve" Parameters:

    rating: Required. 1 - 5, 1 = ohgodwtfisthis, 5 = I want yo babies yo,

    for_translator: Optional. Comments that you can pass on to the translator.

    for_mygengo: Optional. Comments to send to the myGengo staff (kept private
        on myGengo's end)

    public: Optional. 1 (true) / 0 (false, default). Whether myGengo can share
        this feedback publicly.

=item   "reject" Parameters:

    reason: Required. Reason for rejection (must be "quality", "incomplete", "other")

    comment: Required. Explain your rejection, especially if all you put was "other".

    captcha: Required. The captcha image text. Each job in a "reviewable"
        state will have a captcha_url value, which is a URL to an image. This
        captcha value is required only if a job is to be rejected. If the
        captcha is wrong, a URL for a new captcha is also included with the
        error message.

    follow_up: Optional. "requeue" (default) or "cancel". If you choose
        "requeue" the job will be rejected and then passed onto another
        translator. If you choose "cancel" the job will be completely cancelled
        upon rejection.

=back

=cut
sub updateTranslationJobs { 
    my ($self, $jobsStatusObj) = @_;
    return $self->_signAndSend('PUT', '/translate/jobs/', $jobsStatusObj);
}

=head2 postTranslationComment( $id, $comment )

Posts a comment to a job currently on myGengo. Useful for telling translators
extra bits of information as it comes up.

=cut
sub postTranslationJobComment { 
	my ($self, $id, $comment) = @_;
	
	# This makes the call signature a bit nicer for the end-user. :)
    return $self->_signAndSend('POST', '/translate/job/'.$id.'/comment', {
			body => $comment
	});
}

# And now we return this, because... well, that's just how
# Perl modules work. ^_^;
1;

=head1 AUTHOR

@author: Ryan McGrath <ryan@mygengo.com>

=head1 SEE ALSO

@docs: L<http://mygengo.com/api/developer-docs/>

=head1 LICENSE

@copyright: Copyright (c) 2011 myGengo, Inc. (L<http://mygengo.com>)

@license: L<http://mygengo.com/services/api/dev-docs/mygengo-code-license/> New BSD License

=cut
