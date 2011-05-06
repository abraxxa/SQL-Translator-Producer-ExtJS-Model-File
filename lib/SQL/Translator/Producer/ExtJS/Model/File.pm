package SQL::Translator::Producer::ExtJS::Model::File;

#ABSTRACT: ExtJS model file producer

=head1 NAME

SQL::Translator::Producer::ExtJS::Model::File - ExtJS model file producer

=head1 SYNOPSIS

    use SQL::Translator;

    my $translator = SQL::Translator->new(
        parser   => '...',
        producer => 'ExtJS::Model::File',
        producer_args => {
            json_args => {
                space_after => 1,
                indent      => 1,
            },
            extjs_args => {
                extend => 'MyApp.data.Model',
            },
        },
    );
    print $translator->translate();

=head1 DESCRIPTION

Creates ExtJS model classes.

At the moment only version 4 of the ExtJS framework is supported.

=head1 SEE ALSO

F<http://dev.sencha.com/deploy/ext-4.0.0/docs/api/Ext.data.Model.html> for
ExtJS model documentation.

=cut

use strict;
use warnings;
use vars qw[ $VERSION $DEBUG $WARN ];
$DEBUG = 0 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug);
use JSON;

my %translate = (

    #
    # MySQL types
    #
    bigint     => 'int',
    double     => 'float',
    decimal    => 'float',
    float      => 'float',
    int        => 'int',
    integer    => 'int',
    mediumint  => 'int',
    smallint   => 'int',
    tinyint    => 'int',
    char       => 'string',
    varchar    => 'string',
    tinyblob   => 'auto',
    blob       => 'auto',
    mediumblob => 'auto',
    longblob   => 'auto',
    tinytext   => 'string',
    text       => 'string',
    longtext   => 'string',
    mediumtext => 'string',
    enum       => 'string',
    set        => 'string',
    date       => 'date',
    datetime   => 'date',
    time       => 'date',
    timestamp  => 'date',
    year       => 'date',

    #
    # PostgreSQL types
    #
    numeric             => 'float',
    'double precision'  => 'float',
    serial              => 'int',
    bigserial           => 'int',
    money               => 'float',
    character           => 'string',
    'character varying' => 'string',
    bytea               => 'auto',
    interval            => 'float',
    boolean             => 'boolean',
    point               => 'float',
    line                => 'float',
    lseg                => 'float',
    box                 => 'float',
    path                => 'float',
    polygon             => 'float',
    circle              => 'float',
    cidr                => 'string',
    inet                => 'string',
    macaddr             => 'string',
    bit                 => 'int',
    'bit varying'       => 'int',

    #
    # Oracle types
    #
    number   => 'float',
    varchar2 => 'string',
    long     => 'float',
);

=over 4

=item extjs_model_name

This method returns the ExtJS model name for a table and can be overridden
in a subclass.

=cut

sub extjs_model_name {
    my $tablename = shift;
    return ucfirst($tablename);
}

=item produce

This method is called by SQL::Translater::translate and outputs the generated
ExtJS model classes.

=cut

sub produce {
    my $translator = shift;
    $DEBUG = $translator->debug;
    $WARN  = $translator->show_warnings;

    #my $no_comments    = $translator->no_comments;
    my $schema = $translator->schema;
    my $args   = $translator->producer_args;
    my $json   = JSON->new;
    if ( exists $args->{json_args} && ref $args->{json_args} eq 'HASH' ) {
        $json->$_( $args->{json_args}->{$_} )
            for keys %{ $args->{json_args} };
    }

    my %tableoutput;
    my %tableextras;
    foreach my $table ( $schema->get_tables ) {
        debug("table: $table\n");
        my $tname = extjs_model_name( $table->name );
        my @fields;
        foreach my $field ( $table->get_fields ) {
            my $field_params = { name => $field->name };
            my $sqlt_data_type = lc( $field->data_type );
            if ( exists $translate{$sqlt_data_type} ) {
                my $extjs_data_type = $translate{$sqlt_data_type};

                # determine if a numeric column is an int or a really a float
                if ( $extjs_data_type eq 'float' ) {
                    $extjs_data_type = 'int'
                        if $field->size !~ /,/;
                }
                $field_params->{data_type} = $extjs_data_type;
            }

            $field_params->{default_value} = $field->default_value
                if defined $field->default_value;

            push @fields, $field_params;
        }

        # the pk is a single constraint that can consist of one or more fields
        my $pk = $table->primary_key;
        my @pk = map { $_->name } ( $pk->fields )
            if defined $pk;

        my $model = {
            extend => 'Ext.data.Model',
            fields => \@fields,
        };
        $model->{idProperty} = $pk[0]
            if @pk == 1;

        my @assocs;
        foreach my $cont ( $table->get_constraints ) {
            if ( $cont->type eq FOREIGN_KEY ) {

                # FIXME: skip multi-column relationships
                my $related_tname =
                    extjs_model_name( $cont->reference_table );
                my $fieldname         = $cont->field_names->[0];
                my $related_fieldname = $cont->reference_fields->[0];
                push @assocs, {
                    type       => 'belongsTo',
                    model      => $related_tname,
                    primaryKey => "$related_fieldname",
                    foreignKey => "$fieldname",

                    # FIXME: the DBIC relname is not included in the SQLT
                    #        schema and can't be used here
                    associationKey => $cont->name,
                };

                my $hasMany = {
                    type       => 'hasMany',
                    model      => $tname,
                    primaryKey => "$related_fieldname",
                    foreignKey => "$fieldname",

                    # FIXME: the opposite DBIC relname is not included in the
                    #        SQLT schema and can't be used here
                    associationKey => $cont->name,
                };
                push @{ $tableextras{$related_tname} }, $hasMany;
            }
        }
        $model->{associations} = \@assocs
            if @assocs;

        # override any generated config properties
        if ( exists $args->{extjs_args} && ref $args->{extjs_args} eq 'HASH' )
        {
            my %foo = ( %$model, %{ $args->{extjs_args} } );
            $model = \%foo;
        }

        $tableoutput{$tname} = $model;
    }

    # add the hasMany relationships
    foreach my $te ( keys %tableextras ) {

        # skip relationships pointing to unknown tables
        next
            unless exists $tableoutput{$te};
        push @{ $tableoutput{$te}->{associations} }, @{ $tableextras{$te} };
    }

    return join(
        "\n",
        map {
            "Ext.define('$_', "
                . $json->encode( $tableoutput{$_} ) . ");\n"
            } keys %tableoutput
    );
}

=back

1;
