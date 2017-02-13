# * Tools and Flags

INCLUDES=
OCAMLFLAGS=$(INCLUDES) -custom -w -40
OCAMLOPTFLAGS=$(INCLUDES)

OCAMLC=ocamlc $(OCAMLFLAGS)
OCAMLOPT=ocamlopt $(OCAMLOPTFLAGS)
OCAMLDEP=ocamldep $(INCLUDES)
OCAMLDOC=ocamldoc.opt $(INCLUDES) -w -40

METAQUOT=$(shell ocamlfind query ppx_tools)/ppx_metaquot

# * Source files
# NS: list of namespaces (ml)
# NSI: list of namespace interfaces (mli)
# ML: list of modules except namespaces
# MLI: list of module interfaces except namespaces
# MAIN_ML: list of main modules (for testing the library)
# MAIN_MLI: list of main module interfaces

# Namespaces are modules containing module aliases.

# For each source file, its dependencies are generated by
# ocamldep and stored in a file of the same name with
# extension .ml.dep or .mli.dep.

# NOTE: The order ml files matters and should be the same as
# linking order of the corresponding cmos.  All the
# namespaces are linked before the ml files.

NS=generic_util.ml generic_core.ml generic_view.ml generic_fun.ml
NSI=

ML=\
generic_util_app.ml\
generic_util_fun.ml\
generic_util_hash.ml\
generic_util_iter.ml\
generic_util_list.ml\
generic_util_misc.ml\
generic_util_exn.ml\
generic_util_obj.ml\
generic_util_obj_inspect.ml\
generic_util_sum.ml\
generic_util_option.ml\
generic_util_monad.ml\
generic_core_ty.ml\
generic_core_equal.ml\
generic_core_product.ml\
generic_core_desc.ml\
generic_core_ty_desc.ml\
generic_core_patterns.ml\
generic_core_extensible.ml\
generic_core_consumer.ml\
generic_core_desc_fun.ml\
generic_core_antiunify.ml\
generic_core_repr.ml\
generic_view_spine.ml\
generic_view_sumprod.ml\
generic_view_uniplate.ml\
generic_fun_marshal.ml\
generic_fun_uniplate.ml\
generic_fun_equal.ml\

MLI=\
generic_core_antiunify.mli\
generic_core_equal.mli\
generic_core_extensible.mli\
generic_core_consumer.mli\
generic_core_patterns.mli\
generic_core_product.mli\
generic_core_ty_desc.mli\
generic_core_ty.mli\
generic_core_desc_fun.mli\
generic_core_desc.mli\
generic_core_repr.mli\
generic_util_obj.mli\
generic_util_obj_inspect.mli\
generic_util_app.mli\
generic_util_fun.mli\
generic_util_iter.mli\
generic_util_sum.mli\
generic_view_spine.mli\
generic_view_sumprod.mli\
generic_fun_marshal.mli\
generic_fun_uniplate.mli\
generic_fun_equal.mli


# MAIN is the list of main files
MAIN_ML=\
generic_test_marshal.ml\

# interfaces for the main files
MAIN_MLI=

# * Rules
.PHONY: doc ppx lib clean
all: lib ppx doc tests
doc: doc/index.html # doc/dep.dot
lib: generic.cma
ppx: reify
tests: test_marshal

# Library (bytecode)
generic.cma: generic_util_obj_stub.o $(NS:.ml=.cmo) $(ML:.ml=.cmo)
	$(OCAMLC) -custom -o $@ -a $^

reify.cmo: reify.ml
	ocamlc -c -I +compiler-libs -ppx $(METAQUOT) $<
reify: generic.cma reify.cmo
	ocamlc -o $@ -I +compiler-libs ocamlcommon.cma $^

# NOTE about the rule "doc/index.html":
# I added the library as a prerequisite
# because ocamldoc complained of ubound modules otherwise.
# Since it is not a source file, we remove it from the command line
# with "$(wordlist 2, $(words $^), $^)".

doc/index.html: lib $(NS) $(NSI) $(ML) $(MLI)
	mkdir -p doc
	$(OCAMLDOC) -html -t "Generic Programming Library" -intro intro.html -hide Generic_util,Generic_core -d doc $(wordlist 2, $(words $^), $^)

doc/dep.dot: lib $(NS) $(NSI) $(ML) $(MLI)
	mkdir -p doc
	$(OCAMLDOC) -dot -o doc/dep.dot $(wordlist 2, $(words $^), $^)

generic_test_marshal.cmo: generic_test_marshal.ml ppx
	$(OCAMLC) -o $@ -ppx ./reify -c $<

generic_test_marshal.ppx: generic_test_marshal.ml ppx
	$(OCAMLC) -o $@ -dsource -ppx ./reify -c $<

test_marshal: generic.cma generic_test_marshal.cmo
	$(OCAMLC) -o $@ $^

generic_test_gadt.cmo: generic_test_gadt.ml ppx
	$(OCAMLC) -o $@ -ppx ./reify -c $<

generic_test_gadt.ppx: generic_test_gadt.ml ppx
	$(OCAMLC) -o $@ -dsource -ppx ./reify -c $<

test_gadt: generic.cma generic_test_gadt.cmo
	$(OCAMLC) -o $@ $^


# ** Build Dependencies
# IMPORTANT: source files names may not include the character ':'
# Using [sed] we add the dependency file itself as a target.
# sed -r 's:^([^:]*):\1$@ :g' > $@
# that's not necessary for ocaml in fact.

define build_deps =
$(OCAMLDEP) $(foreach ns,$(NS),-map $(ns)) $< > $@
endef

%.mli.dep: %.mli
	$(build_deps)

%.ml.dep: %.ml
	$(build_deps)

$(NS:.ml=.ml.dep): %.ml.dep: %.ml
	$(OCAMLDEP) -as-map $< > $@

# ** Ocaml
define occ=
$(OCAMLC) -c $<
endef

%.cmo: %.ml
	$(occ)

%.cmi: %.mli
	$(occ)

# Generate the mli to stdout
# (we don't want to erase the hand written one)
%.mli.auto: %.ml %.cmo
	$(OCAMLC) -i $<

# This is a static pattern see info: Make > Static Usage
$(NS:.ml=.cmo): %.cmo: %.ml
	$(OCAMLC) -no-alias-deps -w -49 -c $<

$(NSI:.mli=.cmi): %.cmi: %.mli
	$(OCAMLC) -no-alias-deps -w -49 -c $<

# ** C
# Using ocamlc for compiling C automatically deals with the location of ocaml headers
%.o: %.c
	$(occ)

# * Include Dependencies

-include $(ML:.ml=.ml.dep)
-include $(MLI:.mli=.mli.dep)
-include $(NS:.ml=.ml.dep)
-include $(NSI:.mli=.mli.dep)
-include $(MAIN_ML:.ml=.ml.dep)
-include $(MAIN_MLI:.mli=.mli.dep)

# * Clean up

clean:
	rm -f test_marshal reify
	rm -f *.cm[ioxa] *.dep *.o
	rm -rf doc
