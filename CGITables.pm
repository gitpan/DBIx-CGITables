# Copyright (c) Green Smoked Socks Productions y2k

#use CGI::ClientError;
use Carp qw(cluck);
use vars qw($VERSION);

package DBIx::CGITables;

# Remember to update the POD (yes, even the version number) 
# and to tag the cvs (v-major-minor) upon new version numbers
$VERSION="0.00"



__END__

=head1 NAME

DBIx::CGITables 0.00 - Easy DB access from a CGI

=head1 SYNOPSIS

use DBIx::CGITables;

while (my $query=DBIx::CGITables->new()) {

    # Maybe it's better to put this line in the templates? Think about
    # it!  Often text/plain works out as well.  And maybe you would
    # like to make scripts that outputs graphics?  (then again,
    # another template engine should be considered) 

    print "Content-Type: text/html\n\n";

    $query->search_execute_and_do_everything_even_parse_the_template();
}


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

CGITables will recognize a key starting with =, so it's possible to
put up '=execute=1' at a line.  The default value will be 1, so
'=execute' should be equivalent.

If the line contains more than one equal sign which is not at the
start of the line, the other equal signs will be threated as a part of
the value.

Eventually conflicts will appear as the param keys are duplicated in
the query and in the param file.  The default is that the param file
overrides the query.  However, a special code might be inserted in
front of the key=value-pair to override this behaviour.  Those codes
start with '%' since this character is not used by DBIx::Recordset.
In addition they're separated from the key=value couple by one space.
Those codes might also be used in the query:

%=  or
%!	  always override options set other places

%+,	  add new stuff to a comma separated list.  The comma might be
	  replaced by any other character, and to \t and \n, or simply
	  removed. Use '\ ' for a blank and '\\' for a backslash.

%^, 	  prepend, separate from existing value with a comma (same
	  rules as above)

%?        Yield - use this with default values that should only be set 
	  if no other values are set.

%()	  Ignore option (but keep it in template outputs)

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

Drop the first `!Links' to create an independent subquery.

=head2 Supported and future parameters

Possible future parameters:
IncludeParamFile
ParamMacro
Ooups
OtherTemplate
SetSelected

Unfortunately I don't have the time writing more docs due to
deadlines.

=head2 Output to the templates

Unfortunately I don't have the time writing more docs due to
deadlines.

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

=head1 SECURITY

It's up to you to provide proper security.  I think the Right way to
do it is to let the .cgi do the authentication (i.e. by SSL
certificates or transmitting the DB password encrypted)

