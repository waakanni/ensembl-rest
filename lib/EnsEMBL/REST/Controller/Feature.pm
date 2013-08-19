package EnsEMBL::REST::Controller::Feature;

use Moose;
use namespace::autoclean;
use Try::Tiny;
use Bio::EnsEMBL::Utils::Scalar qw/check_ref/;
require EnsEMBL::REST;
EnsEMBL::REST->turn_on_config_serialisers(__PACKAGE__);

__PACKAGE__->config(
  map => {
    'text/x-gff3' => [qw/View GFF3/],
  }
);

=pod

/feature/region/human/X:1000000..2000000?feature=gene

feature = The type of feature to retrieve (gene/transcript/exon/variation/structural_variation/constrained/regulatory)
db_type = The DB type to use; important if someone is doing queries over a non-default DB (core/otherfeatures)
species_set = The compara species set name to look for constrained elements by (mammals)
logic_name = Logic name used for genes
so_term=sequence ontology term to limit variants to

application/json
text/x-gff3

=cut

BEGIN {extends 'Catalyst::Controller::REST'; }

has 'max_slice_length' => ( isa => 'Num', is => 'ro', default => 1e7);

sub species: Chained('/') PathPart('feature/region') CaptureArgs(1) {
  my ( $self, $c, $species) = @_;
  $c->stash(species => $species);
}

sub region_GET {}

sub region: Chained('species') PathPart('') Args(1) ActionClass('REST') {
  my ($self, $c, $region) = @_;
  $c->stash()->{region} = $region;
  my $features;
  try {
    my $slice = $c->model('Lookup')->find_slice($region);
    $self->assert_slice_length($c, $slice);
    $features = $c->model('Feature')->fetch_features();
  }
  catch {
    $c->go('ReturnError', 'from_ensembl', [$_]);
  };
  $self->status_ok($c, entity => $features );
}

sub id_GET {}

sub id: Chained('/') PathPart('feature/id') Args(1) ActionClass('REST') {
  my ($self, $c, $id) = @_;
  my $features;
  try {
    $c->log()->debug('Finding the object');
    my $feature = $c->model('Lookup')->find_object_by_stable_id($id);
    $c->go('ReturnError', 'custom', "The given stable ID does not point to a Feature. Cannot perform overlap") unless check_ref($feature, 'Bio::EnsEMBL::Feature');
    my $slice = $feature->feature_Slice();
    $c->stash->{slice} = $slice;
    $features = $c->model('Feature')->fetch_features();
  } catch {
    $c->go('ReturnError', 'from_ensembl', [$_]);
  };
  $self->status_ok($c, entity => $features );
}

sub translation_GET {}

sub translation: Chained('/') PathPart('feature/translation') Args(1) ActionClass('REST') {
  my ($self, $c, $id) = @_;
  my $features;
  try {
    $c->log()->debug('Finding the object');
    my $translation = $c->model('Lookup')->find_object_by_stable_id($id);
    $features = $c->model('Feature')->fetch_protein_features($translation);
  } catch {
    $c->go('ReturnError', 'from_ensembl', [$_]);
  };
  $self->status_ok($c, entity => $features );
}

with 'EnsEMBL::REST::Role::SliceLength';

__PACKAGE__->meta->make_immutable;

1;
