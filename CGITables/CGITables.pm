# Copyright (c) Green Smoked Socks Productions y2k

package DBIx::CGITables;

use strict;
use Carp qw(cluck);
use vars qw($VERSION $CGI_Class $Template_Class $Recordset_Class $Client_Error_Class);

$CGI_Class='CGI';
$Template_Class='HTML::Template';
$Recordset_Class='DBIx::Recordset';
$Client_Error_Class='CGI::ClientError';

# Remember to update the POD (yes, even the version number) 
# and to tag the cvs (v-major-minor) upon new version numbers
$VERSION="0.00001";

# HACKER INFORMATION
# ==================

# The CGITable class is structured like this:

# Special parameters:
#     $self->{filename}, $self->{query}

# Parameters to DBIx::Recordset:
#     $self->{params}->{$recordset_name}->{$param_key} = $param_value

# Output to template:
#     $self->{output}->{$recordset_name}->[$i]->{$db_key} = $db_value
# NOTE:
#     $self->{output}->{cgi_query}->[$i] = {key=>$param_key, value=>$param_value}
#     $self->{output}->{$query_key} = $query_value
#     (...and more are likely to come...)
# to avoid inprobable, but still potential name clashes, a minus should be 
# prepended to the recordset names.

# Recordset objects:
#     $self->{recordsets}->{$recordset_name}

# Parameters to the template class:
#     $self->{T}->{$option_key}->$option_value

# Special recordset variables (PreserveCase, Debug):
#     $self->{RGV}->{$variable_name}->$variable_value

# Changes might occur to the internal data structure, but the API shouldn't.


sub new {
    # Class identification:
    my $object_or_class = shift; my $class = ref($object_or_class) || $object_or_class;

    # Eventually import params:
    my $self={params=>{default=>($_[0] || {})}};

    # Check for the special !!Filename param:
    $self->{filename}=$self->{params}->{default}->{'!!Filename'} || 
	$ENV{PATH_TRANSLATED} || 
	    undef;
    unless ($self->{filename}) {
	print "What template do you want to parse?";
	# Should have used readline ... but at the other hand, this is _not_ the intended usage
	$self->{filename}=<>;
    }

    # Check for !!ParamFileDir and !!ParamFile
    $self->{param_file}=$self->{params}->{default}->{'!!ParamFile'}
        if exists $self->{params}->{default}->{'!!ParamFile'};
    $self->{param_file_dir}=$self->{params}->{default}->{'!!ParamFileDir'}
        if exists $self->{params}->{default}->{'!!ParamFileDir'};

    # Check for the special !!Query param and/or !!QueryClass:
    if (!($self->{query}=$self->{params}->{default}->{'!!Query'})) {
	$self->{params}->{default}->{'!!QueryClass'}=$CGI_Class
	    unless $self->{params}->{default}->{'!!QueryClass'};
	eval "require ".$self->{params}->{default}->{'!!QueryClass'};
	$self->{query}=$self->{params}->{default}->{'!!QueryClass'}->new;
	return undef if !defined $self->{query};
    }

    bless $self, $class;
    return $self;
}

sub search_execute_and_do_everything_even_parse_the_template {
    my $self=shift;
    my $hash=shift;
    $self->fetch_params_from_query();
    $self->fetch_params_from_file();
    $self->fetch_params_from_hash($hash)
	if defined($hash);
    $self->execute_recordsets();
    $self->parse_template();
}

sub fetch_params_from_query {
    my $self=shift;
    my $q=$self->{query};
    for my $param ($q->param) {
	$self->process_param(0, $param, $q->param($param));
    }
}

sub fetch_params_from_file {
    my $self=shift;
    my $file=$self->find_param_file() || return 0;
    open(FILE, "<$file");
    while(<FILE>) {
	chop;
	$self->process_param(1, $_);
    }
    close(FILE);
}

sub find_param_file {
    my $self=shift;
    return $self->{param_file}
        if exists $self->{param_file};
    my $f=$self->{filename};
    # See the POD for naming conventions
    $f =~ /\.(\w+)$/;
    my $pf="$`.param.$1";
    if (my $d=$self->{param_file_dir}) {
	$pf =~ m|/([^/]+)$|;
	$pf = $d . $1;
    }
    return $pf;
}

sub process_param {
    my $self=shift;
    my $single=shift;
    my $special;
    my $key;
    my $value;
    my $name='default';
    $_=shift;
    if (/^\%([^\ ]*) /) {
	chop($special=$&);
	$_=$';
    }
    
    if (m#^/#) {
	die "stub!";
    }

    if ($single) {
	if (m#^(.+?)\=#) {
	    $key=$1;
	    $value=$';
	} else {
	    $key=$_;
	    $value=1;
	}
    } else {
	$key=$_;
	$value=shift;
    }

    # Ordinary variable
    if (!$special || ($special =~ /^\%[\+\!]/)) {
	$self->{params}->{$name}->{$key}=$value;
    }

    # Ignore!
    elsif ($special eq '%()') {
	return;
    } 

    # Ignore or override!
    elsif ($special eq '%!()') {
	die "stub!";
    } 

    # Recordset Global Variable or Template option
    elsif ($special =~ '%(\w+)') {
	$self->{$1}->{$key}=$value;
    } 

    # Oup!
    elsif (2) {
	die "stub!";
    }

}

sub execute_recordsets {
    my $self=shift;

    # Check for the special !RecordsetClass:
    $self->{recordset_class}=
	$self->{params}->{default}->{'!RecordsetClass'} ||
	    $Recordset_Class;

    eval "require $$self{recordset_class}";

    for (keys %{$self->{'RGV'}}) {
	no strict 'refs';
	if (/^(Debug|PreserveCase)$/) {
	    $ {*{"$$self{recordset_class}::$1"}{SCALAR}}=$self->{'RGV'}->{$_};
	} else {

	    # Somebody (the web user or anyone with access to the
	    # parameter file or the (F)CGI script) has tried tom
	    # modify some variable (s)he's not allowed to update.

	    # I didn't see the need for setting other things than
	    # Debug and PreserveCase, if I'm wrong, the
	    # (Debug|PreserveCase) line above has to be modified
	    # (Better: put it as a package-global variable)

	    warn "Not allowed (check the code for more info)";
	}
    }

    for my $query (keys %{$self->{params}}) {
	$self->{recordsets}->{$query}=
	    tie (@{$self->{output}->{$query}}, 
		 $self->{recordset_class}, 
		 $self->{params}->{$query});
	$self->{recordsets}->{$query}->Execute($self->{params}->{$query});
    }
}

sub parse_template {
    my $self=shift;

    # Check for the special !TemplateClass:
    $self->{template_class}=
	$self->{params}->{default}->{'!TemplateClass'} ||
	    $Template_Class;

    eval "require $$self{template_class}";

    $self->{T}->{filename}=$self->{filename};

    my $template=$self->{template_class}->new(%{$self->{T}});

    # It seems to me that the TIE isn't as powerful as it should be :(
    # This is what we want to do:
#    $template->param(%{$self->{output}});
    # This is what we actually need to do as for now:
    {
	my %helveteheller;
	for (keys %{$self->{output}}) {
	    if (ref $self->{output}->{$_} eq "ARRAY") {
		my $i=0;
		while (my $z=$self->{output}->{$_}->[$i] || undef) {
		    $helveteheller{$_}->[$i++]=$z;
		}
	    } else {
		$helveteheller{$_}=$self->{output}->{$_};
	    }
	}
	$template->param(%helveteheller);
    }
    print $template->output;
}




__END__

=head1 NAME

DBIx::CGITables 0.00001 - Easy DB access from a CGI

=head1 SYNOPSIS

use DBIx::CGITables;

my %parameters=();

my $query=DBIx::CGITables->new(\%parameters));

# Maybe it's better to put this line in the templates? Think about
# it!  Often text/plain works out as well.  And maybe you would
# like to make scripts that outputs graphics?  (then again,
# another template engine should be considered) 

print "Content-Type: text/html\n\n";

$query->search_execute_and_do_everything_even_parse_the_template();


=head1 DESCRIPTION

This module is not finished, hence the synopsis above certainly
doesn't work.  However, I'm releasing the doc already now so _you_ can
provide me with valuable feedback.  I'm expecting to have this up and
running at about the 7th of January.

DBIx::CGITables is made for making database access through CGIs really
easy.

It's completely template-oriented.  The templates are in
HTML::Template format.  You might use a script for generating the
templates from SQL data definitions, but currently this script is only
a collection of hacks.  See DBIx::CGITables::MakeTemplates.  This
might make the system a bit "static".  Gerald Richter
<richter@ecos.de> has another approach based upon HTML::Embperl (not
published at the time I write this), if you'd better like a more
dynamic system.  I think my templates should be easy to modify by
webheads.

The database handling is done by DBIx::Recordset - this module gets
its parametres first from a CGI query, then it might be overridden or
completed by a parameter file, and the caller (your .cgi script or
whatever) is also free to modify or add parameters.

I'm hoping that anybody should get a working (though, probably ugly)
CGI interface to any kind of database simply:

1. Run DBIx::CGITables::MakeTemplates (see the pod)

2. Create the script given above at SYNOPSIS

3. Set up the webserver correct.

4. If you're not satisfied with the look, try to edit the html
   templates.

5. If you're not satisfied with the functionality, try reading the
   rest of this documentation, and the DBIx::Recordset documentation.

6. If you're still not satisfied with the functionality and/or you
   find bugs, hack the code and submit the patches to the mailinglist
   and/or me and/or (if DBIx::Recordset is affected) Gerhard Richter.
   If you're not a perl hacker, or if you don't have time, send a mail
   about what's wrong and/or what's missing to the mailinglist anyway.
   Or privately to me if you don't want to write to a mailinglist.

=head1 PARAMETERS

=head2 How to feed the script with parameters

Firstly, parameters are taken from the query.

Then, parameters on are taken from the I<parameter file>.  This file
is either located in the same folder as the templates, or in a folder
as specified in the parameters.  The parameter file contains options
to DBIx::CGITables and to DBIx::Recordsets.  The parameters should be
at the key=value form, i.e.:

!Table=tablename
!DataSource=...
!NoRGV
!NoT

CGITables will recognize a key starting with =, so it's possible to
put up '=execute=1' at a line.  The default value will be 1, so
'=execute' should be equivalent.

If the line contains more than one equal sign which is not at the
start of the line, the other equal signs will be threated as a part of
the value.

Eventually conflicts will appear as the param keys are duplicated in
the query and in the param file.  The default is that the param file
overrides the query.  This might be changed by a special code inserted
in front of the key=value-pair to override this behaviour.  (I think
too many special codes might be a bit hairy ... but I hope this will
work out anyway).  Those codes start with '%' since this character is
not used by DBIx::Recordset, and they're separated from the key=value
couple by one space.  In addition to suggesting how collitions should
be 

%= or
%! 	  Always override options set other places

%+, 	  Add new stuff to a comma separated list.  The comma might be
	  replaced by any other character, and to \t and \n, or simply
	  removed. Use '\ ' for a blank and '\\' for a backslash.

%^, 	  Prepend, separate from existing value with a comma (same
	  rules as above)

%?        Yield - use this with default values that should only be set 
	  if no other values are set.

%!()      Override or ignore - that is, if the key exists, overwrite,
          if not, ignore.

%() 	  Ignore option (but keep it in template outputs)

%T        Template option.  The key=value is given the Template Class.

%RGV      Recordset Global Variable, most important ones are
          PreserveCase and Debug.

For =execute parameters (see DBIx::Recordset), %= or %! will
`override' other =execute by deleting those.  %+ and %^ will execute
things in order.  The default is to use the priority set by
DBIx::Recordset.

In my older system, I had something called dependent and independent
subqueries.  A `dependent subquery' is a link in the DBIx::Recordset
terminology.  An `independent subquery' would be an independent
DBIx::Recordset object, i.e. for fetching data for a HTML select box.
I also had an option to only `resolve' links when the select returned
only one row - not to waste time fetching too much data when a long
list was fetched.  I guess Recordset handles this more or less
automagically.

`dependent subqueries' (or links, if you'd like) might be handed over
like this:

!Links/-street/!Table=street
!Links/-street/!LinkedField=id
!Links/-street/!MainField=street_id

Drop the first `!Links' to create an independent subquery.  The
primary subquery has the tag "default" without a starting minus.  The
tags should better start with minus, to avoid inprobable though
potential clashes with other output template substitutions.

My earlier systems had some weird syntax for creating misc lists from
the parameters.  DBIx::Recordset uses string splitting.

=head2 First characters

The first character in a parameter key or a line in the parameter file
is often special.  It's a bit messy, but I think it's the easiest way
to do it, anyway - if the rules are obeyed there shouldn't be any
ambiguisities.  Here's a complete list of the first characters:

 % - reserved for a `special handling' code putted in front of the
     real key/param.  This special code is usually describing how to
     handle parameter collitions, but also to tell that the key/param
     should be ignored, or belongs somewhere else (i.e. the
     PreserveCase option is a global variable that might need
     modification)

 / - reserved for extra named Recordset objects.

 ! - reserved for Recordset initialization and important parameters to
     CGITables.

 - - reserved for the name of a named Recordset object.

See the DBIx::Recordset manual for those:
 ' - reserved for a DB column key = value that needs quoting
 # -      ...... numeric value
 \ -      ...... value that should not be quoted (i.e. SQL function)
 + -      ...... value with multiple fields
 * -      ...... Operator for DB column key

 $ - misc options to Recordset.

 = - execute commands to Recordset


=head2 Supported and future parameters

Supported parameters:
!!Filename - defaults to $ENV{PATH_TRANSLATED}
!!ParamFileDir - Default directory for finding ParamFile
!!ParamFile - See below for default.  Ignores ParamFileDir.
!!QueryClass - defaults to 'CGI', but I'm intending to head for
               CGI::Fast
!!Query - defaults to new !!QueryClass
!TemplateClass - defaults to 'HTML::Template'
!RecordsetClass - defaults to 'DBIx::Recordset'

The parameters starting with '!!' (but not !!!) must be set before the
query and parameter file is parsed.

Possible future parameters:
!IncludeParamfile
!ParamMacro
!Ooups
!OtherTemplate
!SetSelected

Unfortunately I don't have the time writing more docs due to
deadlines.

=head2 Output to the templates

Unfortunately I don't have the time writing more docs due to
deadlines.

=head1 TEMPLATE NAMING CONVENTIONS

The templates should have an extention matching /\.(\w+)$/ - typically
sth like mydatabase.CGITables or mydatabase.db or mydatabase.db_html.
The script will then search for the param file mydatabase.param.$1,
i.e. mydatabase.param.db.  It might also use another template if
found, mydatabase.$status.$1, where $status might be one of (in
prioritied order):

    error
    update_ok
    delete_ok
    add_ok    
    found_$n
    found_more

However, statuses are not implemented yet.  found_more will probably
be the first one to be implemented.


=head1 KNOWN BUGS

The code contains this line several places:
   die "stub!";

When this code is executed with warnings, there are some warnings
popping up - but I think I can blame DBIx::Recordset for them.  I have
initiated a dialogue with the author to get rid of them.

This is UNDER DEVELOPMENT and ABSOLUTELY NOT GOOD ENOUGH TESTED.  The
number of unknown bugs is probably high.

=head1 HISTORY

Version 0.

This started as some template cgi system that needed database access.
To allow better flexibility, I made some hacks to allow SQL code to be
inserted into the template.  This was ... ugly, hairy and hacky.  I
expanded it, so the SQL code could be in separate files.  It still was
ugly, hairy and hacky.

Version 1.

I started more or less from scratch, and made a new system, where SQL
code and other parameters to the script could be inserted into a
special parameter file.  The script would "automagically" generate SQL
to select, update, insert and delete rows from tables.  It started out
a lot better than version 0, but it was still hairy, and it certainly
only became worse and worse as more and more features was to be added.

Version 2.

I started from scratch again, this time with object oriented modules -
DBIx::Access and DBIx::CGIAccess.  This time I aimed for cleanliness.
But I think it has grown more messy as more features was to be crammed
in.  I'm currently merging from the Solid database to MySQL - and I'm
a bit horrified because MySQL is case sensitive, and Solid wasn't -
which might mean that I will have to redesign some of the parameter
syntax (I've chosen UPPERCASE for database column names, and lowercase
for misc options).

Version 3.

I registered at CPAN and got a "go" for DBIx::Tables and
DBIx::CGITables.

I scratched my head in a week.  Then I started from scratch again,
discarding DBIx::Tables for DBIx::Recordset.  Now I have one week for
getting this so much up running that it can take over for my previous
system.  ....ooups..!

(the time estimate is already broken, as I'll attend to the
LinuxWorldExpo next week)

Some of the uglyness from earlier versions remain - a quite "ugly"
symbol usage in the param file/query, like "%() !Table=foo".  Maybe I
would have tried doing it in a better way if it wasn't for Recordset
already having parameters prepended by a special character.

=head1 HACKING

Feel free to submit patches, but also normal feedback, bugfixes and
wishlists.

=head1 SECURITY

It's up to you to provide proper security.  I think the Right Way to
do it is to let the .cgi do the authentication (i.e. by SSL
certificates or transmitting the DB login and password encrypted) and
then let the DBMS control what privilegies the user should have.

Another way is to override all potentially harmful parameters to the
DBIx::Recordset, either by the param file or by a hash to the sub with
the long name :)

=head1 AUTHOR

Tobias Brox <tobiasb@funcom.com>

Feedback is appreciated - even flames.  I will eventually put up a
mailing list if I notice any interesst about this module.
