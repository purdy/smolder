package Smolder::RDB::SmokeReport;

use strict;
use warnings;

use Smolder::Email;
use File::Spec::Functions qw(catdir catfile);
use File::Basename qw(basename);
use File::Path qw(mkpath rmtree);
use File::Copy qw(move copy);
use File::Temp qw(tempdir);
use Cwd qw(fastcwd);
use DateTime;
use Smolder::TAPHTMLMatrix;
use Carp qw(croak);
use TAP::Harness::Archive;
use IO::Zlib;
use Smolder::RDB;
use Smolder::Conf qw(DataDir TruncateTestFilenames);
#use Smolder::RDB::SmokeReportManager;
use Smolder::RDB::SmokeReportTag;

use base qw( Rose::DB::Object );

__PACKAGE__->meta->setup(
    table   => 'smoke_report',
    columns => [
        id        => { type => 'serial', not_null => 1, primary_key => 1 },
        project   => { type => 'int',    not_null => 1 },
        developer => { type => 'int',    not_null => 1 },
        added     => { type => 'datetime', not_null => 1, default => 'now' },
        architecture   => { type => 'text', default => '' },
        platform       => { type => 'text', default => '' },
        pass           => { type => 'int',  default => 0 },
        fail           => { type => 'int',  default => 0 },
        skip           => { type => 'int',  default => 0 },
        todo           => { type => 'int',  default => 0 },
        todo_pass      => { type => 'int',  default => 0 },
        test_files     => { type => 'int',  default => 0 },
        total          => { type => 'int',  default => 0 },
        comments       => { type => 'text', default => '' },
        invalid        => { type => 'int',  default => 0 },
        invalid_reason => { type => 'text', default => '' },
        duration       => { type => 'int',  default => 0 },
        purged         => { type => 'int',  default => 0 },
        failed         => { type => 'int',  default => 0 },
        revision       => { type => 'text', default => '' },
    ],
    foreign_keys => [
        project => {
            class       => 'Smolder::RDB::Project',
            key_columns => { project => 'id' },
        },
        developer => {
            class       => 'Smolder::RDB::Developer',
            key_columns => { developer => 'id' },
        },
    ],
    relationships   => [
        tags    => {
            type            => 'one to many',
            class           => 'Smolder::RDB::SmokeReportTag',
            column_map      => { id => 'smokereport' },
            manager_args    => {
                sort_by => Smolder::RDB::SmokeReportTag->meta->table . '.tag',
            },
        },
    ],
);

sub init_db { Smolder::RDB->new }

sub upload_report {
    # TODO - validate params
    my ($class, %args) = @_;

    my $file = $args{file};
    my $dev = $args{developer} ||= Smolder::RDB::Developer->get_guest();
    my $project = $args{project};

    # create our initial report
    my $report = $class->new(
        developer => $dev,
        project => $args{project},
        architecture => ($args{architecture} || ''),
        platform => ($args{platform} || ''),
        comments => ($args{comments} || ''),
        revision => ($args{revision} || ''),
    );

    my $tags = $args{tags} || [];
    $report->add_tags($_);
    $report->save;

    my $results = $report->update_from_tap_archive($file);

    # send an email to all the user's who want this report
    $report->_send_emails($results);

    # move the tmp file to it's real destination
    my $dest = $report->file;
    my $out_fh;
    if ($file =~ /\.gz$/ or $file =~ /\.zip$/) {
        open($out_fh, '>', $dest)
          or die "Could not open file $dest for writing:$!";
    } else {

        #compress it if it's not already
        $out_fh = IO::Zlib->new();
        $out_fh->open($dest, 'wb9')
          or die "Could not open file $dest for writing compressed!";
    }

    my $in_fh;
    open($in_fh, $file)
      or die "Could not open file $file for reading! $!";
    my $buffer;
    while (read($in_fh, $buffer, 10240)) {
        print $out_fh $buffer;
    }
    close($in_fh);
    $out_fh->close();

    # purge old reports
    $project->purge_old_reports();

    return $report;
}

sub update_from_tap_archive {
    my ($self, $file) = @_;
    $file ||= $self->file;

    # our data structures for holding the info about the TAP parsing
    my ($duration, @suite_results, @tests, $label);
    my ($total, $failed, $skipped, $planned) = (0, 0, 0, 0);
    my $file_index = 0;

    # make our tap directory if it doesn't already exist
    my $tap_dir = catdir($self->data_dir, 'tap');
    unless (-d $tap_dir) {
        mkdir($tap_dir) or die "Could not create directory $tap_dir: $!";
    }

    my $meta;
    # keep track of some things on our own because TAP::Parser::Aggregator
    # doesn't handle total or failed right when a test exits early
    my %suite_data;
    my $aggregator = TAP::Harness::Archive->aggregator_from_archive(
        {
            archive => $file,
            made_parser_callback => sub {
                my ($parser, $file, $full_path) = @_;
                $label = TruncateTestFilenames ? basename($file) : $file;

                # clear them out for a new run
                @tests = ();
                ($failed, $skipped) = (0, 0, 0);

                # save the raw TAP stream somewhere we can use it later
                my $new_file = catfile($self->data_dir, 'tap', "$file_index.tap");
                copy($full_path, $new_file) or die "Could not copy $full_path to $new_file. $!\n";
                $file_index++;
            },
            meta_yaml_callback => sub {
                my $yaml = shift;
                $meta = $yaml->[0];
                $duration = $meta->{stop_time} - $meta->{start_time};
            },
            parser_callbacks => {
                ALL => sub {
                    my $line = shift;
                    if ($line->type eq 'test') {
                        my %details = (
                            ok => ($line->is_ok || 0),
                            skip => ($line->has_skip || 0),
                            todo => ($line->has_todo || 0),
                            comment => ($line->as_string || 0),
                        );
                        $failed++ if !$line->is_ok && !$line->has_skip && !$line->has_todo;
                        $skipped++ if $line->has_skip;
                        push(@tests, \%details);
                    } elsif ($line->type eq 'comment' || $line->type eq 'unknown') {
                        my $slot = $line->type eq 'comment' ? 'comment' : 'uknonwn';

                        # TAP doesn't have an explicit way to associate a comment
                        # with a test (yet) so we'll assume it goes with the last
                        # test. Look backwards through the stack for the last test
                        my $last_test = $tests[-1];
                        if ($last_test) {
                            $last_test->{$slot} ||= '';
                            $last_test->{$slot} .= ("\n" . $line->as_string);
                        }
                    }
                },
                EOF => sub {
                    my $parser = shift;
                    # did we run everything we planned to?
                    my $planned = $parser->tests_planned;
                    my $run = $parser->tests_run;
                    my $total;
                    if( $planned && $planned > $run ) {
                        $total = $planned;
                        foreach (1..$planned-$run) {
                            $failed++;
                            push(
                                @tests,
                                {
                                    ok => 0,
                                    skip => 0,
                                    todo => 0,
                                    comment => "test died after test # $run",
                                    died => 1,
                                }
                            );
                        }
                    } else {
                        $total = $run;
                    }

                    my $percent = $total ? sprintf('%i', (($total - $failed) / $total) * 100) : 100;
                    push(
                        @suite_results,
                        {
                            label => $label,
                            tests => [@tests],
                            total => $total,
                            failed => $failed,
                            percent => $percent,
                            all_skipped => ($skipped == $total),
                        }
                    );
                    $suite_data{total} += $total;
                    $suite_data{failed} += $failed;
                  }
            },
        }
    );

    # update
    $self->init(
        pass => scalar $aggregator->passed,
        fail => $suite_data{failed}, # aggregator doesn't calculate these 2 right
        total => $suite_data{total},
        skip => scalar $aggregator->skipped,
        todo => scalar $aggregator->todo,
        todo_pass => scalar $aggregator->todo_passed,
        test_files => scalar @suite_results,
        failed => !!$aggregator->failed,
        duration => $duration,
    );

    # we can take some things from the meta information in the archive
    # if they weren't provided during the upload
    if ($meta->{extra_properties}) {
        foreach my $k (keys %{$meta->{extra_properties}}) {
            foreach my $field qw(architecture platform comments) {
                if (lc($k) eq $field && !$self->get($field)) {
                    $self->set($field => delete $meta->{extra_properties}->{$k});
                    last;
                }
            }
        }
    }

    # generate the HTML reports
    my $matrix = Smolder::TAPHTMLMatrix->new(
        smoke_report => $self,
        test_results => \@suite_results,
        meta => $meta,
    );
    $matrix->generate_html();
    $self->save();

    return \@suite_results;
}

# This method will send the appropriate email to all developers of this Smoke
# Report's project who requested email notification (through their preferences),
# depending on this report's status.

sub _send_emails {
    my ($self, $results) = @_;

    # setup some stuff for the emails that we only need to do once
    my $subject =
      "[" . $self->project->name . "] new " . ($self->failed ? "failed " : '') . "Smolder report";
    my $matrix = Smolder::TAPHTMLMatrix->new(
        smoke_report => $self,
        test_results => $results,
    );
    my $tt_params = {
        report => $self,
        matrix => $matrix,
        results => $results,
    };

    # get all the developers of this project
    my $devs = $self->project->developers();
    foreach my $dev (@$devs) {

        # get their preference for this project
        my $pref = $dev->project_pref($self->project);

        # skip it, if they don't want to receive it
        next
          if ($pref->email_freq eq 'never'
            or (!$self->failed and $pref->email_freq eq 'on_fail'));

        # see if we need to reset their email_sent_timestamp
        # if we've started a new day
        my $last_sent = $pref->email_sent_timestamp;
        my $now = DateTime->now(time_zone => 'local');
        my $interval = $last_sent ? ($now - $last_sent) : undef;

        if (!$interval or ($interval->delta_days >= 1)) {
            $pref->email_sent_timestamp($now);
            $pref->email_sent(0);
            $pref->update;
        }

        # now check to see if we've passed their limit
        next if ($pref->email_limit && $pref->email_sent >= $pref->email_limit);

        # now send the type of email they want to receive
        my $type = $pref->email_type;
        my $email = $dev->email;
        my $error = Smolder::Email->send_mime_mail(
            to => $email,
            name => "smoke_report_$type",
            subject => $subject,
            tt_params => $tt_params,
        );

        warn "Could not send 'smoke_report_$type' email to '$email': $error" if $error;

        # now increment their sent count
        $pref->email_sent($pref->email_sent + 1);
        $pref->update();
    }
}

=head3 data_dir

The directory in which the data files for this report reside.
If it doesn't exist it will be created.

=cut

sub data_dir {
    my $self = shift;
    my $dir = catdir(DataDir, 'smoke_reports', $self->project->id, $self->id);

    # create it if it doesn't exist
    mkpath($dir) if (!-d $dir);
    return $dir;
}

=head3 file

This returns the file name of where the full report file for this
smoke report does (or will) reside. If the directory does not
yet exist, it will be created.

=cut

sub file {
    my $self = shift;
    return catfile($self->data_dir, 'report.tar.gz');
}

=head3 html

A reference to the HTML text of this Test Report.

=cut

sub html {
    my $self = shift;
    return $self->_slurp_file(catfile($self->data_dir, 'html', 'report.html'));
}

=head3 html_test_detail

This method will return the HTML for the details of an individual
test file. This is useful when you only need the details for some
of the test files (such as an AJAX request).

It receives one argument, which is the index of the test file to
show.

=cut

sub html_test_detail {
    my ($self, $num) = @_;
    my $file = catfile($self->data_dir, 'html', "$num.html");

    return $self->_slurp_file($file);
}

=head3 tap_stream

This method will return the file name that holds the recorded TAP stream
given the index of that stream.

=cut

sub tap_stream {
    my ($self, $index) = @_;
    return $self->_slurp_file(catfile($self->data_dir, 'tap', "$index.tap"));
}

# just return the file
# TODO - do something else if the file no longer exists
sub _slurp_file {
    my ($self, $file_name) = @_;
    my $text;
    local $/;
    open(my $IN, $file_name)
      or croak "Could not open file '$file_name' for reading! $!";

    $text = <$IN>;
    close($IN)
      or croak "Could not close file '$file_name'! $!";
    return \$text;
}

=head3 update_all_report_html

Look at all existing reports in the database and regenerate
the HTML for each of these reports. This is useful for development
and also upgrading when the report HTML template files have changed
and you want that change to propagate.

=cut

sub update_all_report_html {
    my $class = shift;
    my $reports = Smolder::RDB::SmokeReportManager->get_smoke_reports(
        query => [ purged => 0 ] );
    foreach my $report (@$reports) {
        warn "Updating report #$report\n";
        eval { $report->update_from_tap_archive() };
        warn " Problem updating report #$report: $@\n" if $@;
    }

}


1;
__END__
CREATE TABLE smoke_report  (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    project         INTEGER NOT NULL,
    developer       INTEGER NOT NULL,
    added           INTEGER NOT NULL,
    architecture    TEXT DEFAULT '',
    platform        TEXT DEFAULT '',
    pass            INTEGER DEFAULT 0,
    fail            INTEGER DEFAULT 0,
    skip            INTEGER DEFAULT 0,
    todo            INTEGER DEFAULT 0,
    todo_pass       INTEGER DEFAULT 0,
    test_files      INTEGER DEFAULT 0,
    total           INTEGER DEFAULT 0,
    comments        BLOB DEFAULT '',
    invalid         INTEGER DEFAULT 0,
    invalid_reason  BLOB DEFAULT '',
    duration        INTEGER DEFAULT 0,
    purged          INTEGER DEFAULT 0,
    failed          INTEGER DEFAULT 0,
    revision        TEXT DEFAULT '',
    CONSTRAINT 'fk_smoke_report_project' FOREIGN KEY ('project') REFERENCES 'project' ('id') ON DELETE CASCADE,
    CONSTRAINT 'fk_smoke_report_developer' FOREIGN KEY ('developer') REFERENCES 'developer' ('id') ON DELETE CASCADE
);
