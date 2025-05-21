% Prolog code for hierarchical animal taxonomy and behavior modeling

% Define taxonomic hierarchy

% Kingdoms
kingdom(animalia).
kingdom(plantae).

% Phyla
phylum(chordata).
phylum(arthropoda).

% Classes
class(mammalia).
class(aves).
class(insecta).

% Orders
order(carnivora).
order(primates).
order(coleoptera).
order(lepidoptera).

% Families
family(felidae).
family(hominidae).
family(coccinellidae).

% Genera
genus(panthera).
genus(homo).
genus(coccinella).

% Species
species(tiger).
species(lion).
species(human).
species(casual_coccinella).

% Establish relationships
% Taxonomic hierarchy
belongs_to(tiger, panthera).
belongs_to(panthera, felidae).
belongs_to(felidae, carnivora).
belongs_to(carnivora, mammalia).
belongs_to(mammalia, chordata).
belongs_to(chordata, animalia).

belongs_to(lion, panthera).
belongs_to(human, homo).
belongs_to(homo, hominidae).
belongs_to(hominidae, primates).
belongs_to(primates, mammalia).

belongs_to(casual_coccinella, coccinella).
belongs_to(coccinella, coccinellidae).
belongs_to(coccinellidae, coleoptera).
belongs_to(coleoptera, insecta).

% Behavioral traits
% Define behaviors
behavior(tiger, stalking).
behavior(tiger, hunting).
behavior(lion, social_hunting).
behavior(human, tool_use).
behavior(human, language).
behavior(casual_coccinella, aphid_consumption).
behavior(casual_coccinella, leaf_feeding).

% Define possible habitats
habitat(tiger, forest).
habitat(lion, savannah).
habitat(human, urban).
habitat(casual_coccinella, gardens).

% Queries for taxonomy
% Find all species within a given genus
species_in_genus(Genus, Species) :-
    belongs_to(Species, Genus),
    species(Species).

% Find all species within a given family
species_in_family(Family, Species) :-
    belongs_to(Species, Genus),
    belongs_to(Genus, Family),
    species(Species).

% Find the full taxonomy path for a species
full_taxonomy(Species, Path) :-
    findall(Level, (
        belongs_to(Species, Genus),
        belongs_to(Genus, Family),
        belongs_to(Family, Order),
        belongs_to(Order, Class),
        belongs_to(Class, Phylum),
        belongs_to(Phylum, Kingdom),
        Path = [Species, Genus, Family, Order, Class, Phylum, Kingdom]
    ), Paths),
    member(Path, Paths).

% Behavioral queries
% Find all behaviors of a species
species_behaviors(Species, Behaviors) :-
    findall(Behavior, behavior(Species, Behavior), Behaviors).

% Find species exhibiting a particular behavior
species_with_behavior(Behavior, SpeciesList) :-
    findall(Species, behavior(Species, Behavior), SpeciesList).

% Find habitats of a species
species_habitat(Species, Habitat) :-
    habitat(Species, Habitat).

% Complex query example: Find all species in a habitat with a specific behavior
species_in_habitat_with_behavior(Habitat, Behavior, SpeciesList) :-
    findall(Species, (
        species_habitat(Species, Habitat),
        behavior(Species, Behavior)
    ), SpeciesList).

% Sample usage
% ?- species_in_genus(panthera, Species).
% ?- full_taxonomy(tiger, Path).
% ?- species_behaviors(human, Behaviors).
% ?- species_in_habitat_with_behavior(forest, hunting, List).