use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Differences;
use SQL::Translator;
use FindBin qw($Bin);

my $xmlfile = "$Bin/data/schema.xml";

die "Can't find test schema $xmlfile"
    unless -e $xmlfile;

my $sqlt = new_ok( 'SQL::Translator', [
    debug => 0,
    parser   => 'XML-SQLFairy',
    filename => $xmlfile,
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
], 'sqlt');

my $out;
lives_ok { $out = $sqlt->translate or die $sqlt->error } 'translate successful';

my $expect = <<EOJS;
Ext.define('Another', {
   "associations": [
      {
         "foreignKey": "another_id",
         "model": "Basic",
         "associationKey": "",
         "type": "hasMany",
         "primaryKey": "id"
      }
   ],
   "extend": "MyApp.data.Model",
   "fields": [
      {
         "data_type": "int",
         "name": "id"
      },
      {
         "data_type": "float",
         "name": "num"
      }
   ],
   "idProperty": "id"
}
);

Ext.define('Basic', {
   "extend": "MyApp.data.Model",
   "associations": [
      {
         "foreignKey": "another_id",
         "model": "Another",
         "associationKey": "",
         "type": "belongsTo",
         "primaryKey": "id"
      }
   ],
   "fields": [
      {
         "data_type": "int",
         "name": "id"
      },
      {
         "data_type": "string",
         "default_value": "hello",
         "name": "title"
      },
      {
         "data_type": "string",
         "default_value": "",
         "name": "description"
      },
      {
         "data_type": "string",
         "name": "email"
      },
      {
         "data_type": "string",
         "name": "explicitnulldef"
      },
      {
         "data_type": "string",
         "default_value": "",
         "name": "explicitemptystring"
      },
      {
         "data_type": "string",
         "default_value": "",
         "name": "emptytagdef"
      },
      {
         "data_type": "int",
         "default_value": "2",
         "name": "another_id"
      },
      {
         "data_type": "date",
         "name": "timest"
      }
   ],
   "idProperty": "id"
}
);
EOJS

eq_or_diff ($out, $expect, 'output ok');

done_testing;
