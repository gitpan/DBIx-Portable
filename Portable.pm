=head1 NAME

DBIx::Portable - Framework for RDBMS-generic apps and schemas

=cut

######################################################################

package DBIx::Portable;
require 5.004;

# Copyright (c) 1999-2003, Darren R. Duncan.  All rights reserved.  This module
# is free software; you can redistribute it and/or modify it under the same terms
# as Perl itself.  However, I do request that this copyright information and
# credits remain attached to the file.  If you modify this module and
# redistribute a changed version then please attach a note listing the
# modifications.  This module is available "as-is" and the author can not be held
# accountable for any problems resulting from its use.

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

1;
__END__

######################################################################

=head1 PREFACE

The DBIx::Portable class currently has no functionality of its own, but rather
contains the collective POD documentation for how to use the DBIx::Portable::*
modules as an integrated but extensible framework.  Any documentation in this
file should be considered to always refer to the aforementioned framework as a
single entity, unless explicitely stated otherwise.  While DBIx::Portable can
be 'used' and it does declare the $VERSION global variable, that variable is
only meant to indicate the version of the whole distribution.  Do not try to
instantiate an object of DBIx::Portable itself or call its functions, but
rather use the other modules as appropriate.

=head1 DEPENDENCIES

=head2 Perl Version

	5.004 (by intent; tested with 5.6)

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	DBI (used by various DBIx::Portable::PDBD::* modules; minimum version unknown)
	DBD::* (used by various DBIx::Portable::PDBD::* modules; minimum versions unknown)

=head1 SYNOPSIS

=head2 Content of settings file "survey_prefs.pl", used by script below:

	my $rh_prefs = {
		pdbi_connect_args => {
			driver => 'DBIx::Portable::PDBD::MySQL-3-23',
			server => 'survey1',
			user => 'joebloe',
			pass => 'fdDF9X0sd7zy',
		},
		question_list => [
			{
				visible_title => "What's your name?",
				type => 'str',
				name => 'name',
				is_required => 1,
			}, {
				visible_title => "What's the combination?",
				type => 'int',
				name => 'words',
			}, {
				visible_title => "What's your favorite colour?",
				type => 'str',
				name => 'color',
			},
		],
	};
	
=head2 Content of a simple CGI script for implementing a web survey:

	#!/usr/bin/perl
	use strict;
	
	&script_main();
	
	sub script_main {
		my $base_url = 'http://'.($ENV{'HTTP_HOST'} || '127.0.0.1').$ENV{'SCRIPT_NAME'};
		my ($curr_mode) = $ENV{'QUERY_STRING'} =~ m/mode=([^&]*)/;
		
		my $form_data_str = '';
		read( STDIN, $form_data_str, $ENV{'CONTENT_LENGTH'} );
		chomp( $form_data_str );
		my %form_values = ();
		foreach my $pair (split( '&', $form_data_str )) {
			my ($key, $value) = split( '=', $pair, 2 );
			next if( $key eq "" );
			$key =~ tr/+/ /;
			$key =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
			$value =~ tr/+/ /;
			$value =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
			$form_values{$key} = $value;
		}
		
		my $fn_prefs = 'survey_prefs.pl';
		
		print
			"Status: 200 OK\n",
			"Content-type: text/html\n\n",
			"<html><head>\n",
			"<title>Simple Web Survey</title>\n",
			"</head><body>\n",
			"<p><a href=\"$base_url?mode=install\">Install Schema</a>\n",
			" | <a href=\"$base_url?mode=remove\">Remove Schema</a>\n",
			" | <a href=\"$base_url?mode=fillin\">Fill In Form</a>\n",
			" | <a href=\"$base_url?mode=report\">See Report</a></p>\n",
			"<hr />\n",
			"<form method=\"POST\" action=\"$base_url?mode=$curr_mode\">\n",
			"<p>\n",
			(&script_make_screen( $fn_prefs, $curr_mode, \%form_values )),
			"</p>\n",
			"<p><input type=\"submit\" name=\"OK\" value=\"Do It Now\" /></p>\n",
			"</form>\n",
			"</body></html>\n";
	}

	sub script_make_screen {
		my ($fn_prefs, $curr_mode, $form_values) = @_;

		my $prefs = do $fn_prefs;
		unless( ref( $prefs ) eq 'HASH' ) {
			return( "Error: can't obtain required preferences hash from '$fn_prefs': ".
				(defined( $prefs ) ? "result not a hash ref, but '$prefs'" : 
				$@ ? "compilation or runtime error of '$@'" : $!) );
		}
		
		eval {
			require DBIx::Portable::PDBI; # also compiles ...::* modules
		};
		if( $@ ) {
			return( "Error: can't compile DBIx::Portable::PDBI/::* modules: $@" );
		}
		
		my $engine = DBIx::Portable::PDBI->new();
		$engine->throw_error( 0 ); # on error, ret result obj, do not throw exception
	
		my $dbh = $engine->execute_command( {
			'type' => 'database_connect',
			'args' => $prefs->{pdbi_connect_args}, # includes what driver to use
		} );
		if( $dbh->is_error() ) {
			return( "Error: can't connect to database: ".$dbh->get_error() );
		}
		
		my $html_output = &script_while_connected( $prefs, $dbh, $curr_mode, $form_values );
		
		my $rv = $dbh->execute_command( {
			'type' => 'database_disconnect',
		} );
		if( $rv->is_error() ) {
			return( "Error: can't disconnect from database: ".$rv->get_error() );
		}
		
		return( $html_output );
	}
	
	sub script_while_connected {
		my ($prefs, $dbh, $curr_mode, $form_values) = @_;
			
		if( $curr_mode eq 'install' ) {
			return( &script_do_install( $prefs, $dbh, $form_values ) );
		}
		
		if( $curr_mode eq 'remove' ) {
			return( &script_do_remove( $prefs, $dbh, $form_values ) );
		}
		
		if( $curr_mode eq 'fillin' ) {
			return( &script_do_fillin( $prefs, $dbh, $form_values ) );
		}
		
		if( $curr_mode eq 'report' ) {
			return( &script_do_report( $prefs, $dbh, $form_values ) );
		}
		
		return( "This is a simple demo.  Click on the menu items to do them." );
	}
	
	sub script_to_install {
		my ($prefs, $dbh, $form_values) = @_;
	
		# TO DO NEXT
	}
	
	sub script_to_remove {
		my ($prefs, $dbh, $form_values) = @_;
	
		# TO DO NEXT
	}
	
	sub script_to_fillin {
		my ($prefs, $dbh, $form_values) = @_;
	
		# TO DO NEXT
	}
	
	sub script_to_report {
		my ($prefs, $dbh, $form_values) = @_;
	
		# TO DO NEXT
	}


	# TO DO:		
	#	PROCESS QUESTION LIST INTO:
	#		- TABLE DEFINITION; SIZES ARE DEFAULT FOR BASE TYPES GIVEN
	#		- VIEW/SELECT/INSERT DEFINITIONS
	#		- HTML FILL IN FORM AND RESULT TABLE

	1;

=head1 DESCRIPTION

The DBIx::Portable framework is intended to support complex (or simple)
database-using applications that are easily portable across databases because
common product-specific details are abstracted away.  These include the RDBMS
product and vendor name, what dialect of SQL its scripting or query interface
uses, whether the product uses SQL at all or some other method of querying, how
query results are returned, what features the RDBMS supports, how to manage
connections, how to manage schema, how to manage stored procedures, and perhaps
how to manage users.  The main thing that this framework will not be doing in
the forseeable future is managing the installation and configuration of the
RDBMS itself, which may be on the same machine or a different one.

There are two main types of functionality that the DBIx::Portable framework is
designed to implement; this functionality may be better described in different
groupings.

The first functionality type is the management (creation, modification,
deletion) of the schema in a database, including: tables, keys, constraints,
relations, sequences, views, stored procedures, triggers, and users.  This type
of functionality typically is used infrequently and sets things up for the main
functionality of your database-using application(s). In some cases, typically
with single-user desktop applications, the application may install its own
schema, and/or create new database files, when it starts up or upon the user's
prompting; this can be analogous to the result of a "New..." (or "Save As...")
command in a desktop financial management or file archiving application; the
application would then carry on to use the schema as its personal working
space.  In other cases, typically with multiple-user client-server
applications, one "Installer" or "Manager" type application or process with
exclusive access will be run once to create the schema, and then a separate
application or process will be run to make use of it as a shared working space.

The second functionality type is the management (creation, modification,
deletion) of the data in a database, including such operations as: direct
selects from single or multiple tables or views, direct inserts or updates or
deletes of records, calling stored procedures, using sequences, managing
temporary tables, managing transactions, managing data integrity.  This type of
functionality typically is used frequently and comprises the main functionality
of your database-using application(s).  In some cases, typically with
public-accessible websites or services, all or most users will just be viewing
data and not changing anything; everyone would use the same database user and
they would not be prompted for passwords or other security credentials.  In
other cases, typically with private or restricted-access websites or services,
all or most users will also be changing data; everyone would have their own
real or application-simulated database user, whom they log in as with a
password or other credentials; as the application implements, these users can
have different activity privileges, and their actions can be audited.

The DBIx::Portable framework can be considered a low-level service because it 
allows a fine level of granularity or detail for the commands you can make of it 
and the results you get back; you get a detailed level of control.  But it is 
not low-level in the way that you would be entering any raw SQL, or even 
small fragments of raw SQL; that is expressly avoided because it would expose 
implementation details that aren't true on all databases.  Rather, this framework 
provides the means for you to specify in an RDBMS-generic fashion exactly what it 
is you want to happen, and your request is mapped to native or emulated functionality 
for the actual RDBMS that is being used, to do the work.  The implementation or 
mapping is different for each RDBMS being abstracted away, and makes maximum use of 
that database's built-in functionality.  Thereby, the DBIx::Portable framework 
achieves the greatest performance possible while still being 100% RDBMS-generic.

This differs from other database abstraction modules or frameworks that I am
aware of on CPAN, since the others tend to either work towards the
lowest-common-denominator database while emulating more complex functionality,
which is very slow, or more often they provide a much more limited number of
abstracted functions and expect you to do things manually (which is specific to
single databases or non-portable) with any other functionality you need.  With
many modules, even the abstracted functions tend to accept sql fragments as
part of their input, which in the broadest sense makes those non-portable as
well.  With my framework I am attempting the "holy grail" of maximum
portability with maximum features and maximum speed, which to my knowledge none
of the existing solutions on CPAN are doing, or would be able to do short of a
full rewrite.  This is largely why I am starting a new module framework rather 
than trying to help patch an existing solution; I believe a rewrite is needed.

=head1 PROGRESS

In an effort to keep things simpler for development, the first few releases of
this distribution will contain some of the intended features, while others will
be left out for now, but be dealt with later at an appropriate time.

The first few releases should allow you to: connect to (or open) an existing
database, create tables, views, stand-alone stored procedures, and stand-alone
stored functions in the schema of the database user that you connect as,
validate said schema, select from multiple tables or views, modify (IUD) data
in tables, call stand-alone stored procedures and functions, create and use
temporary tables.

The first few releases will likely not provide the means to: create a new
database, create database users or modify their privileges, see schema of users
that you didn't connect as (unless there are public synonyms), pay attention to
or enforce user privileges that the underlying RDBMS product doesn't implement
itself, implement transactional data integrity where the underlying RDBMS
product doesn't do it, enforce foreign key constraints or other data
constraints where the underlying RDBMS doesn't do it, support multiple
transaction contexts on a single database connection.

The first few releases might but not necessarily: obtain read locks for data
consistency, lock records for update, pay attention to or start and end
transactions (commit or rollback), create or call database packages containing
stored procedures and functions, create triggers, create or use sequences.

On databases that don't support sub-selects (eg: MySQL before 4.1.x) or unions
(eg: MySQL before 4.0.x) natively, DBIx::Portable::PDBD::* will try to
emulate complex select commands by creating temporary tables in the database to
hold results of inner selects.  This would keep all the implementation work
inside the RDBMS product where it should be, with only the final resulting
row-set being returned to the Perl application.  However, it is possible that
this will only work if the database user being connected as has the privileges
to create tables, which isn't always the case for DML-only users; on the other
hand, temporary tables may not require said permissions.  There may also be
problems with reliability of the results if someone else is modifying the
inputs for the temporary tables before they are all built; this may change
later when proper read locks are used.

=head1 SYNTAX

These classes do not export any functions or methods, so you need to call them
using object notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.  If you are inheriting any class for
your own modules, then that often means something like B<$self-E<gt>method()>. 

=head1 STRUCTURE

The modules composing the DBIx::Portable framework are grouped into two main
categories, which can be called "Portable RDBMS Interface" and "Portable RDBMS
Drivers".  The first group is in some ways the core of the framework, since it
is always used to coordinate activities, and it is what stands squarely between
the second group and the main logic of your applications; the second group
requires the first, but the latter is not technically true.  There potentially 
are a third group of modules, which can be called "Portable RDBMS Wrappers"; 
this group sits on top of the first group and provides alternative interfaces; 
the third group would never talk directly to the second group.

=head2 PORTABLE RDBMS INTERFACE

The "Portable RDBMS Interface", or "PDBI" for short, is a framework unto itself
which defines its own programming language if you will.  This language could be
considered a new SQL variant, in that it has the features to represent a
non-ambiguous structured definition of any task that you would want a database
to do. But it is different in that one should always be using it in a "fully
parsed" form, which is a multi-dimensional data structure, and usually
encapsulated by a few objects; the PDBI framework is comprised mainly of these
objects.

The main reason for having no serialized representation, or "SQL statement", is
that this framework is intended primarily for a data-driven application
programming model, where the applications use a "data dictionary" to control
what work it is doing.  The PDBI framework is intended to save these
applications from having to convert their data dictionaries into SQL manually;
the various "attributes" or "nodes" of a PDBI object can often correspond
directly to individual attributes stored in a data dictionary, so applications
can simply copy them over as simple scalar values.  But even non-data-driven
programs would benefit from the PDBI framework, since it still is a convenient
way to define exactly what you want to happen without you having to know any
SQL.  For cases when you want a less verbose interface, it is easy to add new
ones on top.

Also, serialized SQL representations are avoided in the core because they can
add a lot of processing overhead and can be a lot more error prone; it is like
having to write a paragraph from scratch rather than just filling in some
blanks.  That said, it should be easy enough to add a layer on top of the
existing interface that does SQL parsing.

Each of the PDBI modules is one of two types, which can be called "active" and
"container".  Methods of an "active" class will or might interact with a
database while they are executing (which is generally an external environment),
and that interaction may alter the current state of the database (eg: open or
close connection, read or write data, read or write schema).  Methods of a
"container" class, by contrast, will only alter Perl data structures within
objects of that class, or create new container objects (they do not read from
or write to the environment).  Container objects are often used as input to
active object methods, to help describe what the active method should be doing.
Container objects can be serialized into a settings file or database for later
use if desired, but it doesn't make sense to do this with active objects; the
latter can usually be cached in memory during the short term, however.  All
active class objects must be instantiated from other active class object
methods; use DBIx::Portable::PDBI->new() to get the first active object.

These are the main PDBI classes:

=over 4

=item 0

B<DBIx::Portable::PDBI> - This active class is inherited by all other active
PDBI classes, and it provides functionality to talk to or manage PDBD modules.
Its main task is to define the execute_command() method, which takes a Command
object saying what should be done next and returns or throws a Result object
saying what actually was done (or what errors there were).  For some command
types, execute_command() may only start the process that needs doing (eg: get a
select cursor), and invoking execute_command() again on the Result object
(which is a subclass) will continue or finish the process (eg: fetch a row). 
Instantiated by itself, this class stores globals that are shared by all
drivers or connections.  Subclasses include: Result, Connection.

=item 0

B<DBIx::Portable::PDBI::Command> - This container class describes an action
that needs to be done against a database; the action may include several steps,
and all of them must be done when executing the Command.  A Command object has
one mandatory string property named 'type' (eg: 'database_connect',
'table_create', 'data_insert'), which sets the context for all of its other
properties, which are in a hash property named 'args'.  Elements of 'args' 
often include other PDBI class objects like 'Table' or 'DataType'.

=item 0

B<DBIx::Portable::PDBI::Result> - This active class is inherited by all PDBI
classes that would be returned from or thrown by an execute_command() method,
and it contains the return values or errors of a Command.  Its main task is to
implement the is_error() and get_error() methods, which say whether the Command
failed or not, and if so then why.  Some commands (eg: 'database_disconnect')
have no other meta-data or data to return, while others do (eg: 'data_select').  
Subclasses include: Connection.

=item 0

B<DBIx::Portable::PDBI::Connection> - This active class represents a connection
to a database instance, and the simplest database applications use only one.
You instantiate a Connection object by executing a Command of type
'database_connect'; that command usually takes 4 arguments, the first of which
is mandatory: 'driver' is a string having the name of the PDBD module to use,
which also defines what RDBMS product is being used; 'server' is the name of
the specific database instance to use; 'user' is the username to authenticate
yourself against a multi-user database as; 'pass' is the associated password.

=item 0

B<DBIx::Portable::PDBI::Cursor> - This active class represents a cursor over a
rowset that is being selected from a database.  You instantiate a Cursor object
by executing a command of type 'data_select'; that command usually takes 1
argument, which is mandatory: 'view' is a View object that describes the select
statement being run, including what columns it has and their datatypes, what
the source tables are, how they are joined, what the row filters are, sort
order, and row limiting or paging.  

=item 0

B<DBIx::Portable::PDBI::DataType> - This container class describes a simple
data type, which serves as meta-data for a single scalar unit of data, or a
column whose members are all of the same data type, such as is in a regular
database table or in row-sets read from or to be written to one.  This class
would be used both when manipulating database schema and when manipulating
database data.

=item 0

B<DBIx::Portable::PDBI::Table> - This container class describes a single
database table, and would be used for such things as managing schema for the
table (eg: create, alter, destroy), and describing the table's "public
interface" so other functionality like views or various DML operations know how
to use the table. In its simplest sense, a Table object consists of a table
name, a list of table columns, a list of keys, a list of constraints, and a few
other implementation details.  This class does not describe anything that is
changed by DML activity, such as a count of stored records, or the current
values of sequences attached to columns.  This class can generate Command
objects having types of: 'table_verify', 'table_create', 'table_alter',
'table_destroy'.

=item 0

B<DBIx::Portable::PDBI::DataSet> - This container class is meta-data from which
DML command templates can be generated.  Conceptually, a DataSet looks like a
Table, since both represent or store a matrix of data, which has uniquely
identifiable columns, and rows which can be uniquely identifiable but may not
be.  But unlike a Table, a DataSet does not have a name.  In its simplest use,
a DataSet is an interface to a single database table, and its public interface
is identical to that of said table; this interface can be used to fetch or
modify data stored in the table.  This class can generate Command objects
having types of: 'data_select', 'data_insert', 'data_update', 'data_delete',
'data_lock', 'data_unlock'.  I<Note: this paragraph was a rough draft.>

=item 0

B<DBIx::Portable::PDBI::View> - This container class describes a single
database view, and would be used for such things as managing schema for the
view (eg: create, alter, destroy), and describing the view's "public interface"
(it looks like a table, with columns and rows) so other functionality like
various DML operations or other views know how to use the view.  Conceptually
speaking, a database view is an abstracted interface to one or more database
tables which are related to each other in a specific way; a view has its own
name and can generally be used like a table.  A View object has only two
properties, which are a name and a DataSet object; put another way, a View
object simply associates a name with a DataSet object.  This class does not
describe anything that is changed by DML activity, such as a count of stored
records, or the current values of sequences attached to columns.  This class
can generate Command objects having types of: 'view_verify', 'view_create',
'view_alter', 'view_destroy'.

=back

Other classes that may be added later include: Transaction (action for separate 
transaction contexts within a connection); Driver (action for globals shared by 
all connections implemented with the same PDBD); Database (container for 
database details not specific to tables); Procedure (container for details 
about stored procedures); other descriptors for triggers, users, whatever.

=head2 PORTABLE RDBMS DRIVERS

The "Portable RDBMS Drivers", or "PDBD" for short, is a pseudo-framework which
implements all of the commands that the PDBI describes.  For the most part,
each of the PDBD modules is specialized for a particular RDBMS product.  Each
would generate SQL, send those statements to the database, and return the
results. It is possible that the SQL generation will be put in separate modules
from those that call the database, but it remains to be seen.

There is no strict rule that says there has to be a single PDBD module per
database product; there could be several that implement the PDBI commands in
different ways, or each one could be specialized for different versions of a
product, which have different features to make use of.  For example, there
could be separate modules for MySQL version 3.x (the current "stable" release),
version 4.0.x (which adds unions), and version 4.1.x (which adds subselects);
most of their code would likely be shared. Similarly, Oracle 7 and 8 and 9
could have different modules optimized for their built-in features.

While the DBIx::Portable framework doesn't specifically require it, most PDBD
modules will likely be implemented using the popular and mature "DBI" and
"DBD::*" modules found on CPAN.  These modules provide the actual binary
interfaces to the database product, so all DBIx::Portable has to do is generate
SQL and add features which each product doesn't natively support, where
possible.  Only the PDBD modules would contain any "use DBI" or
"DBI->connect()" statements; the PDBI modules would never talk to DBI objects
directly and they would never expose a DBI object to the application code that
calls the PDBI methods (this is unlike practically every other database
abstraction module). This means, if for some reason there is a database whose
binary interface is only implemented by a module on CPAN that isn't a DBD::*
module, you can still use that database with DBIx::Portable.  Of course, what
you can talk to is entirely up to the discression of the PDBD module
implementers; it is quite possible that nothing but the DBI/DBD::* modules will
ever be used, as they continue to add their own support for new databases.

All PDBD modules need to have a specific public interface, which certain PDBI
modules will call them with, but they don't have to personally implement all of
it.  Any PDBD module can be defined to inherit from a different one, and just
override any unique functionality. Most likely, there will be a single PDBD
module that defines all of the required public modules but each of those does
little or nothing, perhaps just printing out a debugging message saying they
were called.  All of the other PDBD modules would inherit from this one and
override its methods.  It is quite possible that there will be multiple levels
of inheritence.  For example, a middle level may implement ANSI-complient SQL,
and the others only override where their RDBMS differs from the ANSI SQL
standard.  Or, the code for initializing DBI objects or some thin wrappers for
its methods may be in a middle module.

These are the main PDBD classes:

=over 4

=item 0

B<DBIx::Portable::PDBD> - This class defines the specific public API that all
PDBD classes must have, which is what the appropriate PDBI classes will call
them with; it is an error condition if you pass a module as a driver and that
module doesn't subclass this one; also, do not instantiate this class directly,
as it doesn't implement the methods it declares.

=item 0

B<DBIx::Portable::PDBD::ANSI> - This class implements most PDBD methods using
SQL that is compliant to the ANSI SQL standard.  It is not intended to be used
by itself, but rather subclassed by another PDBD module for a specific RDBMS
product.  This class assumes that DBI and DBD::* modules will be used for
implementation, so it uses DBI objects and methods internally.  It currently
does not implement the 'database_connect' command because subclasses should be
choosing which DBD::* module to use internally.

=item 0

B<DBIx::Portable::PDBD::MySQL-3-23> - This class implements a driver for
talking to MySQL 3.23.x databases.  This version of MySQL does not support most
kinds of sub-selects and unions, so this driver emulates that functionality by
creating temporary tables; you can only use those features if you connect as a
user with privileges to make temporary tables.  Note that 3.23.54 is the latest
release and is considered production-quality (stable) since 2001.01.22.

=item 0

B<DBIx::Portable::PDBD::MySQL-4-0> - This class implements a driver for talking
to MySQL 4.0.x databases.  This version of MySQL does not support most kinds of
sub-selects, so this driver emulates that functionality by creating temporary
tables; you can only use those features if you connect as a user with
privileges to make temporary tables.  Note that 4.0.7 is the latest release and
is considered gamma-quality (soon to be stable?).

=item 0

B<DBIx::Portable::PDBD::MySQL-4-1> - This class implements a driver for talking
to MySQL 4.1.x databases.  This version of MySQL does support most kinds of
sub-selects and unions, so this driver does not need to emulate them, and you
can use these features even when you connect as a user that can not create
temporary tables.  Note that 4.1.0 is the latest release and is considered
alpha-quality (perhaps stable in a year?).

=item 0

B<DBIx::Portable::PDBD::Oracle-8> - This class implements a driver for talking
to Oracle 8.x databases.

=item 0

B<DBIx::Portable::PDBD::Oracle-9> - This class implements a driver for talking
to Oracle 9.x databases.  Note that Oracle 9 is the first version of the Oracle 
database that runs under Mac OS X (10.2 and later).

=back

All other databases in common use should be supported as well; the ones in the
above module list are vendors that I have used personally; I need to research
others to know what versions exist or are stable or are in common use.  Other
RDBMS products include: Sybase, PostgreSQL, DB2, SQL-Server, OpenBase,
FrontBase, Valentina, Informix, ODBC, and others.

=head2 PORTABLE RDBMS WRAPPERS

The "Portable RDBMS Wrappers", or "PDBW" for short, is a set of independant
modules which provide an alternative to the highly verbose PDBI interface.
These modules would probably take one of several different forms.

One form of PDBW is a value-added extension, possibly more
application-specific, such as an interpreter for data dictionaries.  For
example, a data dictionary could say that an application is composed of screens
or forms that are related in a certain way; each screen would contain several
controls of various types, and some controls may correspond to specific columns
in database tables. The module in question would determine from the data
dictionary what needs to be retrieved from the database to support a particular
screen, and ask the PDBI modules to go get it.  Similarly, if the application
user edits data on the screens that should then be saved back to the database,
the PDBW module would ask the PDBI modules to save it. On the other side of
things, it is quite possible that the data dictionary for the application is
itself stored in the database, and so the PDBI modules can be asked to fetch
portions of it as the PDBW module requires.

Another form of PDBW is an interface customizer or simplifier.  if you know
that certain details of your commands to PDBI will always be the same, or you
just like to express your needs in a different way, you can take care of the
default values in a wrapper module, so that the rest of your application simply
has to provide inputs that aren't always the same.

Another form of PDBW is a data parser or serializer.  For example, to convert
database output to XML or convert XML to a database command (although, certain
kinds of XML processing may be better implemented in the PDBI/PDBD layers for
performance reasons, but if so it would still be an extension).

Another form of PDBW is a command parser for various SQL dialects.  For
example, if you want to quickly port an application, which already includes SQL
statements that are tailored to a specific database product, to a different
database for which it is incompatible, a PDBW module could parse that statement
into the object representation that PDBI uses.  This is effectively an
SQL-to-SQL translator.  I would expect that, citing reasons of performance or
application code simplicity, one wouldn't want to use this functionality
long-term, but replace the SQL with PDBI object definitions later.

Finally, one could also make PDBWs which emulate other database abstraction
solutions for similar reasons to the above, which is a different type of quick
porting.  Since the intended feature set of DBIx::Portable should be a superset
of existing solutions' feature sets, it should be possible to emulate them with
it.  

A possible namespace for non-application-specific PDBW classes could be 
DBIx::Portable::PDBW::*, but none are included with this distribution.

=head1 MODULE DETAILS

Below is some more detailed documentation for a few classes, as they have been 
written.  These are by no means complete and are subject to change.

=head2 DBIx::Portable::PDBI::DataType

This PDBI module is a container class that describes a simple data type, which
serves as meta-data for a single scalar unit of data, or a column whose members
are all of the same data type, such as is in a regular database table or in
row-sets read from or to be written to one.  This class would be used both when
manipulating database schema and when manipulating database data.  

Here is some sample code for defining common data types with this class:

	my %data_types = map { 
			( $_->{name}, DBIx::Portable::PDBI::DataType->new( $_ ) ) 
			} (
		{ 'name' => 'boolean', 'base_type' => 'boolean', },
		{ 'name' => 'byte' , 'base_type' => 'int', 'size' => 1, }, #  3 digits
		{ 'name' => 'short', 'base_type' => 'int', 'size' => 2, }, #  5 digits
		{ 'name' => 'int'  , 'base_type' => 'int', 'size' => 4, }, # 10 digits
		{ 'name' => 'long' , 'base_type' => 'int', 'size' => 8, }, # 19 digits
		{ 'name' => 'float' , 'base_type' => 'float', 'size' => 4, },
		{ 'name' => 'double', 'base_type' => 'float', 'size' => 8, },
		{ 'name' => 'datetime', 'base_type' => 'datetime', },
		{ 'name' => 'str4' , 'base_type' => 'str', 'size' =>  4, 'store_fixed' => 1, },
		{ 'name' => 'str10', 'base_type' => 'str', 'size' => 10, 'store_fixed' => 1, },
		{ 'name' => 'str30', 'base_type' => 'str', 'size' =>    30, },
		{ 'name' => 'str2k', 'base_type' => 'str', 'size' => 2_000, },
		{ 'name' => 'bin1k' , 'base_type' => 'binary', 'size' =>  1_000, },
		{ 'name' => 'bin32k', 'base_type' => 'binary', 'size' => 32_000, },
	);

These are the main class properties:

=over 4

=item 0

B<name> - This mandatory string property is a convenience for calling code or
users to easily know when multiple pieces of data are of the same type.  Its
main programatic use is for hashing DataType objects.  That is, if the same
data type is used in many places, and those places don't want to have their own
DataType objects or share references to one, they can store the 'name' string
instead, and separately have a single DataType object in a hash to lookup when
the string is encountered in processing.  Only the other class properties are
what the PDBD modules actually use when mapping the PDBI data types to native
RDBMS product data types.  This property is case-sensitive.

=item 0

B<base_type> - This mandatory string property is the starting point for PDBD
modules to map this data type to a native RDBMS product data type.  It is
limited to a pre-defined set of values which are what any DBIx::Portable
modules should know about: 'boolean', 'int', 'float', 'datetime', 'str',
'binary'.  More base types could be added later, but it should be possible to
define what you want by setting other appropriate class properties along with
one of the above base types.  This property is set case-insensitive but it is
stored and returned in lower-case.

=item 0

B<size> - This integer property is recommended for use with all base_type
values except 'boolean' and 'datetime', for which it has no effect.  With the
base types of 'int' and 'float', it is the fixed size in bytes used to store a
numerical data, which also determines the maximum storable number.  With the
'binary' base_type, it is the maximum size in bytes that can be stored, but the
actual size is only as large as the binary data being stored.  With the 'str'
base_type, it is the maximum size in characters that can be stored, but the
actual size is only as large as the string data being stored; however, if the
boolean property 'store_fixed' is true then a fixed size of characters is
always allocated even if it isn't filled, where possible.  If 'size' is not
defined then it will default to 4 for 'int' and 'float', and to 250 for 'str'
and 'boolean'.  This behaviour may be changed to default to the largest value
possible for the base data type in question, but that wasn't done because the
maximum varies based on the implementing RDBMS product, and maximum may not be 
what is usually desired.

=item 0

B<store_fixed> - This boolean property is optional for use with the 'str'
base_type, and it has no effect for the other base types.  While string data is
by default stored in a flexible and space-saving format (like 'varchar'), if
this property is true, then the PDBD modules will attempt to map to a fixed
size type instead (like 'char') for storage.  With most database products,
fixed-size storage is only applicable to fields with smaller size limits, such
as 255 or less.  Setting this property won't necessarily change what value is
stored or retrieved, but with some products the returned values may be padded
with spaces.

=back

Other class properties may be added in the future where appropriate.  Some such
properties can describe constraints that would apply to all data of this type,
such as that it must match the format of a telephone number or postal code or
ip address, or it has to be one of a specific set of pre-defined (not looked up
in an external list) values; however, this functionality may be too advanced to
do until later, or would be implemented elsewhere.  Other possible properties
might be 'hints' for certain PDBDs to use an esoteric native data type for
greater efficiency or compatability. This class would be used both when
manipulating database schema and when manipulating database data.
	
=head2 DBIx::Portable::PDBI::Table

This PDBI module is a container class that describes a single database table,
and would be used for such things as managing schema for the table (eg: create,
alter, destroy), and describing the table's "public interface" so other
functionality like views or various DML operations know how to use the table.
In its simplest sense, a Table object consists of a table name, a list of table
columns, a list of keys, a list of constraints, and a few other implementation
details.  This class does not describe anything that is changed by DML
activity, such as a count of stored records, or the current values of sequences
attached to columns.  This class can generate Command objects having types of: 
'table_verify', 'table_create', 'table_alter', 'table_destroy'.

Here is sample code for defining a few tables with this class:

	my %table_info = map { 
			( $_->{name}, DBIx::Portable::PDBI::Table->new( $_ ) ) 
			} (
		{
			'name' => 'user_auth',
			'column_list' => [
				{
					'name' => 'user_id', 'data_type' => 'int', 'is_req' => 1,
					'default_val' => 1, 'auto_inc' => 1,
				},
				{ 'name' => 'login_name'   , 'data_type' => 'str20'  , 'is_req' => 1, },
				{ 'name' => 'login_pass'   , 'data_type' => 'str20'  , 'is_req' => 1, },
				{ 'name' => 'private_name' , 'data_type' => 'str100' , 'is_req' => 1, },
				{ 'name' => 'private_email', 'data_type' => 'str100' , 'is_req' => 1, },
				{ 'name' => 'may_login'    , 'data_type' => 'boolean', 'is_req' => 1, },
				{ 
					'name' => 'max_sessions', 'data_type' => 'byte', 'is_req' => 1, 
					'default_val' => 3, 
				},
			],
			'unique_key_list' => [
				{ 'name' => 'PRIMARY'         , 'column_list' => [ 'user_id'      , ], },
				{ 'name' => 'sk_login_name'   , 'column_list' => [ 'login_name'   , ], },
				{ 'name' => 'sk_private_email', 'column_list' => [ 'private_email', ], },
			],
			'primary_key' => 'PRIMARY', # from unique keys list, others are surrogate
		},
		{
			'name' => 'user_profile',
			'column_list' => [
				{ 'name' => 'user_id'     , 'data_type' => 'int'   , 'is_req' => 1, },
				{ 'name' => 'public_name' , 'data_type' => 'str250', 'is_req' => 1, },
				{ 'name' => 'public_email', 'data_type' => 'str250', 'is_req' => 0, },
				{ 'name' => 'web_url'     , 'data_type' => 'str250', 'is_req' => 0, },
				{ 'name' => 'contact_net' , 'data_type' => 'str250', 'is_req' => 0, },
				{ 'name' => 'contact_phy' , 'data_type' => 'str250', 'is_req' => 0, },
				{ 'name' => 'bio'         , 'data_type' => 'str250', 'is_req' => 0, },
				{ 'name' => 'plan'        , 'data_type' => 'str250', 'is_req' => 0, },
				{ 'name' => 'comments'    , 'data_type' => 'str250', 'is_req' => 0, },
			],
			'unique_key_list' => [
				{ 'name' => 'PRIMARY'       , 'column_list' => [ 'user_id'    , ], },
				{ 'name' => 'sk_public_name', 'column_list' => [ 'public_name', ], },
			],
			'primary_key' => 'PRIMARY', # from unique keys list, others are surrogate
			'foreign_key_list => [
				{ 
					'name' => 'fk_user',
					'foreign_table' => 'user_auth',
					'column_list' => [ 
						{ 'name' => 'user_id', 'foreign_column' => 'user_id' },
					], 
				},
			],
		},
		{
			'name' => 'user_pref',
			'column_list' => [
				{ 'name' => 'user_id'   , 'data_type' => 'int'     , 'is_req' => 1, },
				{ 'name' => 'pref_name' , 'data_type' => 'entitynm', 'is_req' => 1, },
				{ 'name' => 'pref_value', 'data_type' => 'generic' , 'is_req' => 0, },
			],
			'unique_key_list' => [
				{ 'name' => 'PRIMARY', 'column_list' => [ 'user_id', 'pref_name', ], },
			],
			'primary_key' => 'PRIMARY', # from unique keys list, others are surrogate
			'foreign_key_list => [
				{ 
					'name' => 'fk_user',
					'foreign_table' => 'user_auth',
					'column_list' => [ 
						{ 'name' => 'user_id', 'foreign_column' => 'user_id' },
					], 
				},
			],
		},
		{
			'name' => 'person',
			'column_list' => [
				{
					'name' => 'person_id', 'data_type' => 'int', 'is_req' => 1,
					'default_val' => 1, 'auto_inc' => 1,
				},
				{ 'name' => 'alternate_id', 'data_type' => 'str20' , 'is_req' => 0, },
				{ 'name' => 'name'        , 'data_type' => 'str100', 'is_req' => 1, },
				{ 'name' => 'sex'         , 'data_type' => 'str1'  , 'is_req' => 0, },
				{ 'name' => 'father_id'   , 'data_type' => 'int'   , 'is_req' => 0, },
				{ 'name' => 'mother_id'   , 'data_type' => 'int'   , 'is_req' => 0, },
			],
			'unique_key_list' => [
				{ 'name' => 'PRIMARY'        , 'column_list' => [ 'person_id'   , ], },
				{ 'name' => 'sk_alternate_id', 'column_list' => [ 'alternate_id', ], },
			],
			'primary_key' => 'PRIMARY', # from unique keys list, others are surrogate
			'foreign_key_list => [
				{ 
					'name' => 'fk_father',
					'foreign_table' => 'person',
					'column_list' => [ 
						{ 'name' => 'father_id', 'foreign_column' => 'person_id' },
					], 
				},
				{ 
					'name' => 'fk_mother',
					'foreign_table' => 'person',
					'column_list' => [ 
						{ 'name' => 'mother_id', 'foreign_column' => 'person_id' },
					], 
				},
			],
		},
	);

These are the main class properties:

=over 4

=item 0

B<name> - This mandatory string property is a unique identifier for this table 
within a single database, or within a single schema in a multiple-schema 
database.  This property is case-sensitive so it works with database products 
that have case-sensitive schema (eg: MySQL), but it is still a good idea to 
never name your tables such that they would conflict if case-insensitive, so 
that the right thing can happen with a case-insensitive database product 
(eg: Oracle in standard usage).

=item 0

B<column_list> - This mandatory array property is a list of the column
definitions that constitute this table.  Each array element is a hash (or
pseudo-object) having these properties:

=over 4

=item 0

B<name> - This mandatory string property is a unique identifier for this column
within the table currently being defined.  It has the same case-sensitivity
rules governing the table name itself.

=item 0

B<data_type> - This mandatory property is either a DataType object or a string
having the name of a DataType object, which can be used to lookup said object
that was defined somewhere else but near-by.  It is case-sensitive.

=item 0

B<is_req> - This boolean property is optional but recommended; if not
explicitely set, it will default to false, unless the column has been marked as
part of a unique key, in which case it will default to true.  If this property
is true, then the column will require a value, and any DML operations that try
to set the column to null will fail.  (A true value is like 'not null' and a
false value is like 'null'.)

=item 0

B<default_val> - This scalar property is optional and if set its value must be
something that is valid for the data type of this column.  The current
behaviour for what would happen if it isn't is undefined.

=item 0

B<auto_inc> - This boolean property is optional for use when the base_type of
this column's data type is 'int', and it has no effect for the other base types
(but support for other base types may be added).  If this property is true,
then the PDBD modules will attempt to mark this column as auto-incrementing;
its value will be set from a special table-specific numerical sequence that
increments by 1.  This property may be replaced with a different feature.

=back

=item 0

B<unique_key_list> - This array property is a list of the unique keys (or keys
or unique constraints) that apply to this table.  Each array element is a hash
(or pseudo-object) for describing a single key and has these properties:
'name', 'column_list'.  The 'name' property is a mandatory string and is a
unique identifier for this key within the table; it has the same
case-sensitivity rules governing table and column names.  The 'column_list'
property is an array with at least one element; each element is a string that
must match the name of a column declared in this table.  A key can be composed 
of one or more columns, and more than one key may use the same column.

=item 0

B<primary_key> - This string property is optional and if it is set then it must
match the 'name' of an 'unique_key_list' element in the current table.  This
property is for identifying the primary key of the table; any other elements of
'unique_key_list' that exist will become surrogate (alternate) keys. 
Additionally, any columns used in a primary key must have their 'is_req'
properties set to true (as required by either ANSI SQL or some databases).

=item 0

B<foreign_key_list> - This array property is a list of the foreign key
constraints that are on column sets.  Given that foreign keys define a
relationship between two tables where values must be present in table A in
order to be stored in table B, this class is defined to describe a relationship
between said two tables in the object representing table B.  Each array element
is a hash (or pseudo-object) for describing a single constraint and has these
properties: 'name', 'foreign_table', 'column_list'.  The 'name' property is a
mandatory string and is a unique identifier for this constraint within the
table; it has the same case-sensitivity rules governing table and column names.
The 'foreign_table' property is a mandatory string which must match the 'name'
of a previously defined table.  The 'column_list' property is an array with at
least one element; each element is a hash having two values; the 'name' value
is a mandatory string that must match the name of a column declared in this
table; the 'foreign_column' value is a mandatory string that must match the
name of a column declared in the table whose name is in 'foreign_table'.  A
foreign key constraint can be composed of one or more columns, and more than
one constraint may use the same column; for each column used in this table, a
separate column must be matched in the other table, and the other column needs
to have the same data type.

=item 0

B<index_list> - This array property has the same format as 'unique_key_list'
but it is not for creating unique constraints; rather, it is for indicating
that we will often be doing DML operations that lookup records by values in
specific column-sets, and we want to index those columns for better fetch
performance (but slower modify performance).  Note that indexing already
happens with column-sets used for unique or presumably foreign keys, so 
specifying them here as well is probably redundant.

=back

=head2 DBIx::Portable::PDBI::DataSet

This PDBI module is a container class that is meta-data from which DML command
templates can be generated.  Conceptually, a DataSet looks like a Table, since
both represent or store a matrix of data, which has uniquely identifiable
columns, and rows which can be uniquely identifiable but may not be.  But
unlike a Table, a DataSet does not have a name.  In its simplest use, a DataSet
is an interface to a single database table, and its public interface is
identical to that of said table; this interface can be used to fetch or modify
data stored in the table.  This class can generate Command objects having types
of: 'data_select', 'data_insert', 'data_update', 'data_delete', 'data_lock',
'data_unlock'.  I<Note: this paragraph was a rough draft.>

=head2 DBIx::Portable::PDBI::View

This PDBI module is a container class that describes a single database view,
and would be used for such things as managing schema for the view (eg: create,
alter, destroy), and describing the view's "public interface" (it looks like a
table, with columns and rows) so other functionality like various DML
operations or other views know how to use the view.  Conceptually speaking, a
database view is an abstracted interface to one or more database tables which
are related to each other in a specific way; a view has its own name and can
generally be used like a table.  A View object has only two properties, which
are a name and a DataSet object; put another way, a View object simply
associates a name with a DataSet object.  This class does not describe anything
that is changed by DML activity, such as a count of stored records, or the
current values of sequences attached to columns.  This class can generate
Command objects having types of: 'view_verify', 'view_create', 'view_alter',
'view_destroy'.

Here is sample code for defining a few views with this class (rough draft):

	my %view_info = map { 
			( $_->{name}, DBIx::Portable::PDBI::View->new( $_ ) ) 
			} (
		{
			'name' => 'user',
			'source_list' => [
				{ 'name' => 'user_auth', 'source' => $table_info{user_auth}, },
				{ 'name' => 'user_profile', 'source' => $table_info{user_profile}, },
			],
			'column_list' => [
				{ 'name' => 'user_id'      , 'source' => 'user_auth'   , },
				{ 'name' => 'login_name'   , 'source' => 'user_auth'   , },
				{ 'name' => 'login_pass'   , 'source' => 'user_auth'   , },
				{ 'name' => 'private_name' , 'source' => 'user_auth'   , },
				{ 'name' => 'private_email', 'source' => 'user_auth'   , },
				{ 'name' => 'may_login'    , 'source' => 'user_auth'   , },
				{ 'name' => 'max_sessions' , 'source' => 'user_auth'   , },
				{ 'name' => 'public_name'  , 'source' => 'user_profile', },
				{ 'name' => 'public_email' , 'source' => 'user_profile', },
				{ 'name' => 'web_url'      , 'source' => 'user_profile', },
				{ 'name' => 'contact_net'  , 'source' => 'user_profile', },
				{ 'name' => 'contact_phy'  , 'source' => 'user_profile', },
				{ 'name' => 'bio'          , 'source' => 'user_profile', },
				{ 'name' => 'plan'         , 'source' => 'user_profile', },
				{ 'name' => 'comments'     , 'source' => 'user_profile', },
			],
			'join_list' => [
				{
					'lhs_source' => 'user_auth', 
					'rhs_source' => 'user_profile',
					'join_type' => 'left',
					'column_list' => [
						{ 'lhs_column' => 'user_id', 'rhs_column' => 'user_id', },
					],
				},
			],
		},
		{
			'name' => 'person_with_parents',
			'source_list' => [
				{ 'name' => 'self', 'source' => $table_info{person}, },
				{ 'name' => 'father', 'source' => $table_info{person}, },
				{ 'name' => 'mother', 'source' => $table_info{person}, },
			],
			'column_list' => [
				{ 'name' => 'self_id'    , 'source' => 'self'  , 'column' => 'person_id', },
				{ 'name' => 'self_name'  , 'source' => 'self'  , 'column' => 'name'     , },
				{ 'name' => 'father_id'  , 'source' => 'father', 'column' => 'person_id', },
				{ 'name' => 'father_name', 'source' => 'father', 'column' => 'name'     , },
				{ 'name' => 'mother_id'  , 'source' => 'mother', 'column' => 'person_id', },
				{ 'name' => 'mother_name', 'source' => 'mother', 'column' => 'name'     , },
			],
			'foreign_key_list => [
				{
					'lhs_source' => 'self', 
					'rhs_source' => 'father',
					'join_type' => 'left',
					'column_list' => [
						{ 'lhs_column' => 'person_id', 'rhs_column' => 'person_id', },
					],
				},
				{
					'lhs_source' => 'self', 
					'rhs_source' => 'mother',
					'join_type' => 'left',
					'column_list' => [
						{ 'lhs_column' => 'person_id', 'rhs_column' => 'person_id', },
					],
				},
			],
		},
	);

=head1 AUTHOR

Copyright (c) 1999-2003, Darren R. Duncan.  All rights reserved.  This module
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.  However, I do request that this copyright information and
credits remain attached to the file.  If you modify this module and
redistribute a changed version then please attach a note listing the
modifications.  This module is available "as-is" and the author can not be held
accountable for any problems resulting from its use.

I am always interested in knowing how my work helps others, so if you put this
module to use in any of your own products or services then I would appreciate
(but not require) it if you send me the website url for said product or
service, so I know who you are.  Also, if you make non-proprietary changes to
the module because it doesn't work the way you need, and you are willing to
make these freely available, then please send me a copy so that I can roll
desirable changes into the main release.

Address comments, suggestions, and bug reports to B<perl@DarrenDuncan.net>.

=head1 SEE ALSO

perl(1), DBI, DBD::*.

=cut
