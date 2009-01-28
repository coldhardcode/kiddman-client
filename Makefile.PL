# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;

name 'Kiddman-Client';
all_from 'lib/Kiddman/Client.pm';

requires 'File::Spec';
requires 'JSON::XS';
requires 'Moose';
requires 'MooseX::Types';
requires 'parent';
requires 'Tree::Simple';
requires 'Tree::Simple::VisitorFactory';
requires 'YAML::XS';

install_script glob('script/*.pl');
auto_install;
WriteAll;
