package Genome::SoftwareResult::ParamInputBase;

use strict;
use warnings;
use Genome;

class Genome::SoftwareResult::ParamInputBase {};

sub __display_name__ {
    my $self = shift;
    my $name = $self->name;
    my $sr = $self->software_result;
    my @value;
    my $value_class_name = $self->value_class_name;
    my $value_id = $self->value_id;
    my $value;
    if ($value_class_name) {
        $value = $value_class_name->get($value_id);
    }
    else {
        $value = UR::Value::Text->get($value_id);
    }
    return "$name:" . $value->__display_name__;
}

# this will sync up new columns with the old ones
# once all old snapshots are gone, we will switch to the new columns and remove this

sub create {
    my $class = shift;
    my $bx = $class->define_boolexpr(@_);

    unless ($bx->value_for('value_class_name')) {
        my $sr_id = $bx->value_for('software_result_id');

        my $sr = Genome::SoftwareResult->get($sr_id);
        die "invalid software result id $sr_id!" unless $sr;

        my $name = $bx->value_for('name');
        $name =~ s/-.*//;
        die "no name specified when constructing a " . $class unless $name;

        my $pmeta = $sr->__meta__->property($name);
        die "no property $name found on software result " . $sr->__display_name__ unless $pmeta;

        my $value_class_name = $pmeta->_data_type_as_class_name;

        $bx = $bx->add_filter(value_class_name => $value_class_name);
    }

    my $self = $class->SUPER::create($bx);
    return unless $self;
    $self->_new_name($self->name);
    $self->_new_value($self->value_id);
    return $self;
}

sub delete {
    my $self = shift;
    my $sr = $self->software_result;
    my $rv = $self->SUPER::delete(@_);
    $sr->recalculate_lookup_hash();
    return $rv;
}

# this has the functionality of the old "value" accessor
# we wanted to ensure we were no longer dependent on it
# ..but the HTML view needs something generic which will work
sub _value_scalar_or_object {
    my $self = shift;
    my $name = $self->name;
    return $self->software_result->$name(@_);
}

sub value {
    my $classname = ref($_[0]) || $_[0];
    Carp::confess("The system is calling value() on a " . $classname . ".  The old functionality of value() is not compatible with the new.  Code should go throuh the accessor on the software result, or call _value_scalar_or_object _IF_ it is internal to the profile")
}

1;
