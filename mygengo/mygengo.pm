# mygengo.pm
#
# A Perl interface for the mygengo API. Not much to this,
# should be pretty self explanatory. ;)
#
# For reference as to what this library actually does in regards
# to authentication and the like, visit the docs located at the @docs
# link below.
#
# @author: Ryan McGrath <ryan@mygengo.com>
# @docs: http://mygengo.com/api/developer-docs/
# @category: myGengo
# @package: API Client Library
# @copyright: Copyright (c) 2011 myGengo, Inc. (http://mygengo.com)
# @license: http://mygengo.com/services/api/dev-docs/mygengo-code-license New BSD License

package MyGengo;

use strict;
use warnings;

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

# sub new()
#
# Every API caller should instantiate a new client based off this,
# and then use the appropriate calls below.
#
# use MyGengo;
# my $mygengo = MyGengo->new('pubKey', 'privKey', '1');
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
        apiURL => (defined($useSandbox) ? 'http://api.sandbox.mygengo.com/v1.1' : 'http://api.mygengo.com/v1.1'),
        client => $client,
        json => $json
    };

    bless($self, $class);
    return $self;
}

# _signAndSend(...)
#
# Internal method used for POSTing/PUTing data. Left 'available'
# in case anybody wants to use it for tinkering.
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

# _signAndRequest(...)
#
# Internal method used for POSTing/PUTing data. Left 'available'
# in case anybody wants to use it for tinkering.
sub _signAndRequest {
    my ($self, $method, $endpoint, $data) = @_;
    my $time = time();
    
    my $hmac = Digest::HMAC->new($self->{privateKey}, "Digest::SHA1");
    $hmac->add($time);

    my $url = '?ts='.$time.'&api_key='.uri_escape($self->{publicKey});
    $url .= '&api_sig='.$hmac->hexdigest;

    if(defined($data)) {
        foreach my $key ($data) { 
            if(defined($data->{$key})) {
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

# getAccountStats()
#
# Retrieves account stats for the authenticated account, returns it
# as a Perl object and such.
sub getAccountStats {
    my ($self) = @_;
    return $self->_signAndRequest('GET', '/account/stats/');
}

# getAccountBalance()
#
# Retrieves the balance for the authenticated account in question.
sub getAccountBalance { 
    my ($self) = @_;
    return $self->_signAndRequest('GET', '/account/balance/');
}

# getTranslationJob(id)
#
# Retrieves a job from myGengo with the specified id.
#
# @param id - ID of a job to retrieve
sub getTranslationJob { 
    my ($self, $id) = @_;
    return $self->_signAndRequest('GET', '/translate/job/'.$id);
}

# getTranslationJobs(status, timestamp_after, count)
#
# Acts like a filter for jobs you've previously submitted.
#
# @param status - Optional. "unpaid", "available", "pending", "reviewable", "approved", "rejected", or "canceled".
# @param timestamp_after - Optional. Epoch timestamp from which to filter submitted jobs.
# @param count - Optional. Defaults to 10.
sub getTranslationJobs { 
    my ($self, $status, $timestamp_after, $count) = @_;
    
    return $self->_signAndRequest('GET', '/translate/jobs/', {
        status => $status,
        timestamp_after => $timestamp_after,
        count => $count
    });
}

# getTranslationJobBatch(id)
#
# Gets a batch of jobs associated with a given job ID.
#
# @param id - ID of a job to pull associated jobs for.
sub getTranslationJobBatch {
    my ($self, $id) = @_;
    return $self->_signAndRequest('GET', '/translate/jobs/'.$id);
}

# getTranslationJobComments
#
# Gets comments for a given Job, given the id.
#
# @param id - ID of a job to pull comments for.
sub getTranslationJobComments { 
    my ($self, $id) = @_;
    return $self->_signAndRequest('GET', '/translate/job/'.$id.'/comments');
}

# getTranslationJobFeedback
# 
# Gets feedback for a given job, given the ID.
#
# @param id - ID of a job to pull feedback for.
sub getTranslationJobFeedback { 
    my ($self, $id) = @_;
    return $self->_signAndRequest('GET', '/translate/job/'.$id.'/feedback');
}

# getTranslationJobRevisions
#
# Gets revisions for a given job, given the id. Revisions are created each time a translator 
# or Senior Translator updates the job.
#
# @param id - ID of a job to pull revisions for.
sub getTranslationJobRevisions { 
    my ($self, $id) = @_;
    return $self->_signAndRequest('GET', '/translate/job/'.$id.'/revisions');
}

# getTranslationJobRevision
#
# Gets a specific revision on a given job.
#
# @param id - ID of a job to pull this revision off of.
# @param revision_id - Revision ID to pull.
sub getTranslationJobRevision { 
    my ($self, $id, $revision_id) = @_;
    return $self->_signAndRequest('GET', '/translate/job/'.$id.'/revisions/'.$revision_id);
}

# deleteTranslationJob
#
# Deletes a job on the myGengo side. You can only cancel a job if it has not been started already by a translator.
#
# @param id - ID of a job to cancel/delete on the myGengo side.
sub deleteTranslationJob { 
    my ($self, $id) = @_;
    return $self->_signAndRequest('DELETE', '/translate/job/'.$id);
}

# getServiceLanguagePairs
#
# Returns supported translation language pairs, tiers, and credit prices.
#
# @param lc_src - Optional. A source language code to filter the results to relevant pairs.
sub getServiceLanguagePairs { 
    my ($self, $lc_src) = @_;
    
    return $self->_signAndRequest('GET', '/translate/service/language_pairs', {
        lc_src => $lc_src
    });
}

# getServiceLanguages
#
# Returns a list of supported languages and their language codes.
sub getServiceLanguages { 
    my ($self) = @_;
    return $self->_signAndRequest('GET', '/translate/service/languages');
}

# postTranslationJob
#
# POSTs a job to myGengo for translators to pick up and work on.
#
# @param job - a hash/object that follows our payload structure. See:
#     http://mygengo.com/api/developer-docs/payloads/ (submissions)
sub postTranslationJob {
    my ($self, $job) = @_;
    return $self->_signAndSend('POST', '/translate/job/', {job => $job});
}

# postTranslationJobs
#
# Post multiple jobs at once over to myGengo; accepts two extra optional parameters.
# See this page for more information about this endpoint: 
# http://mygengo.com/api/developer-docs/methods/translate-jobs-post/
#
# @param jobs - An Array of job hashes/object to send over.
# @param process - A Boolean indicating whether this should be processed/paid for immediately.
# @param as_group - If true, one translator will work on all these jobs together.
sub postTranslationJobs { 
    my ($self, $jobs, $process, $as_group) = @_;
    
    return $self->_signAndSend('POST', '/translate/jobs', {
        jobs => $jobs,
        process => $process,
        as_group => $as_group
    });
}

# determineTranslationCost
#
# Gets an estimate for a job cost; follows the group job (postTranslationJob) method
# structure, without process/as_group.
#
# @param jobs - An Array of job hashes/object to send over.
sub determineTranslationCost { 
    my ($self, $jobs) = @_;
    return $self->_signAndSend('POST', '/translate/job', $jobs);
}

# updateTranslationJob
#
# Updates a job with a few different possible statuses.
#
# @param id - ID of the job in question that needs updating.
# @param statusObj - A hash/object with various properties. See below...
#
# "purchase" Parameters: None
# "revise" Parameters:
#     - comment: Optional. A comment describing the revision.
# "approve" Parameters:
#     - rating: Required. 1 - 5, 1 = ohgodwtfisthis, 5 = I want yo babies yo,
#     - for_translator: Optional. Comments that you can pass on to the translator.
#     - for_mygengo: Optional. Comments to send to the myGengo staff (kept private on myGengo's end)
#     - public: Optional. 1 (true) / 0 (false, default). Whether myGengo can share this feedback publicly.
# "reject" Parameters:
#     - reason: Required. Reason for rejection (must be "quality", "incomplete", "other")
#     - comment: Required. Explain your rejection, especially if all you put was "other".
#     - captcha: Required. The captcha image text. Each job in a "reviewable" state will have a captcha_url value, which 
#         is a URL to an image. This captcha value is required only if a job is to be rejected. If the captcha is wrong, a 
#         URL for a new captcha is also included with the error message.
#     - follow_up: Optional. "requeue" (default) or "cancel". If you choose "requeue" the job will be rejected and then 
#         passed onto another translator. If you choose "cancel" the job will be completely cancelled upon rejection.
sub updateTanslationJob { 
    my ($self, $id, $statusObj) = @_;
    return $self->_signAndSend('PUT', '/translate/job/'.$id, $statusObj);
}

# updateTranslationJobs
#
# Updates multiple jobs with a few different possible statuses.
#
# @param jobsStatusObj - An Array of hashes/objects with various properties. Each object must
#     have a "job_id" set, as well as an action object (like the details below).
#
# "purchase" Parameters: None
# "revise" Parameters:
#     - comment: Optional. A comment describing the revision.
# "approve" Parameters:
#     - rating: Required. 1 - 5, 1 = ohgodwtfisthis, 5 = I want yo babies yo,
#     - for_translator: Optional. Comments that you can pass on to the translator.
#     - for_mygengo: Optional. Comments to send to the myGengo staff (kept private on myGengo's end)
#     - public: Optional. 1 (true) / 0 (false, default). Whether myGengo can share this feedback publicly.
# "reject" Parameters:
#     - reason: Required. Reason for rejection (must be "quality", "incomplete", "other")
#     - comment: Required. Explain your rejection, especially if all you put was "other".
#     - captcha: Required. The captcha image text. Each job in a "reviewable" state will have a captcha_url value, which 
#         is a URL to an image. This captcha value is required only if a job is to be rejected. If the captcha is wrong, a 
#         URL for a new captcha is also included with the error message.
#     - follow_up: Optional. "requeue" (default) or "cancel". If you choose "requeue" the job will be rejected and then 
#         passed onto another translator. If you choose "cancel" the job will be completely cancelled upon rejection.
sub updateTanslationJobs { 
    my ($self, $jobsStatusObj) = @_;
    return $self->_signAndSend('PUT', '/translate/jobs/', $jobsStatusObj);
}

# postTranslationComment
# 
# Posts a comment to a job currently on myGengo. Useful for telling translators extra bits of 
# information as it comes up.
#
# @param id - ID of the job to post this comment to.
# @param comment - comment to post to this job.
sub postTranslationJobComment { 
	my ($self, $id, $comment) = @_;
	
	# This makes the call signature a bit nicer for the end-user. :)
    return $self->_signAndSend('POST', '/translate/job/'.$id.'/comment', {
		comment => {
			body => $comment
		}
	});
}

# And now we return this, because... well, that's just how
# Perl modules work. ^_^;
1;
