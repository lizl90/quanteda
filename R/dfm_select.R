#' Select features from a dfm or fcm
#'
#' This function selects or removes features from a \link{dfm} or \link{fcm},
#' based on feature name matches with \code{pattern}.  The most common usages
#' are to eliminate features from a dfm already constructed, such as stopwords,
#' or to select only terms of interest from a dictionary.
#'
#' @param x the \link{dfm} or \link{fcm} object whose features will be selected
#' @inheritParams pattern
#' @param selection whether to \code{keep} or \code{remove} the features
#' @param valuetype the type of pattern matching: \code{"glob"} for "glob"-style
#'   wildcard expressions; \code{"regex"} for regular expressions; or
#'   \code{"fixed"} for exact matching. See \link{valuetype} for details.
#'
#'   For \code{dfm_select}, \code{pattern} may also be a \link{dfm}; see Value
#'   below.
#' @param case_insensitive ignore the case of dictionary values if \code{TRUE}
#' @param min_nchar,max_nchar numerics specifying the minimum and maximum length
#'   in characters for features to be removed or kept; defaults are 1 and
#'   \href{https://en.wikipedia.org/wiki/Donaudampfschiffahrtselektrizitätenhauptbetriebswerkbauunterbeamtengesellschaft}{79}.
#'    (Set \code{max_nchar} to \code{NULL} for no upper limit.) These are
#'   applied after (and hence, in addition to) any selection based on pattern
#'   matches.
#' @param verbose if \code{TRUE} print message about how many pattern were
#'   removed
#' @details \code{dfm_remove} and \code{fcm_remove} are simply a convenience
#'   wrappers to calling \code{dfm_select} and \code{fcm_select} with
#'   \code{selection = "remove"}.
#'
#'   \code{dfm_keep} and \code{fcm_keep} are simply a convenience wrappers to
#'   calling \code{dfm_select} and \code{fcm_select} with \code{selection =
#'   "keep"}.
#' @note This function selects features based on their labels.  To select
#'   features based on the values of the document-feature matrix, use
#'   \code{\link{dfm_trim}}.
#' @return A \link{dfm} or \link{fcm} object, after the feature selection has
#'   been applied.
#'
#'   When \code{pattern} is a \link{dfm} object, then the returned object will
#'   be identical in its feature set to the dfm supplied as the \code{pattern}
#'   argument. This means that any features in \code{x} not in the dfm provided
#'   as \code{pattern} will be discarded, and that any features in found in the
#'   dfm supplied as \code{pattern} but not found in \code{x} will be added with
#'   all zero counts.  Because selecting on a dfm is designed to produce a
#'   selected dfm with an exact feature match, when \code{pattern} is a
#'   \link{dfm} object, then the following settings are always used:
#'   \code{case_insensitive = FALSE}, and \code{valuetype = "fixed"}.
#'
#'   Selecting on a \link{dfm} is useful when you have trained a model on one
#'   dfm, and need to project this onto a test set whose features must be
#'   identical.  It is also used in \code{\link{bootstrap_dfm}}.  See examples.
#' @export
#' @keywords dfm
#' @examples
#' my_dfm <- dfm(c("My Christmas was ruined by your opposition tax plan.",
#'                "Does the United_States or Sweden have more progressive taxation?"),
#'              tolower = FALSE, verbose = FALSE)
#' my_dict <- dictionary(list(countries = c("United_States", "Sweden", "France"),
#'                           wordsEndingInY = c("by", "my"),
#'                           notintext = "blahblah"))
#' dfm_select(my_dfm, my_dict)
#' dfm_select(my_dfm, my_dict, case_insensitive = FALSE)
#' dfm_select(my_dfm, c("s$", ".y"), selection = "keep", valuetype = "regex")
#' dfm_select(my_dfm, c("s$", ".y"), selection = "remove", valuetype = "regex")
#' dfm_select(my_dfm, stopwords("english"), selection = "keep", valuetype = "fixed")
#' dfm_select(my_dfm, stopwords("english"), selection = "remove", valuetype = "fixed")
#'
#' # select based on character length
#' dfm_select(my_dfm, min_nchar = 5)
#'
#' # selecting on a dfm
#' txts <- c("This is text one", "The second text", "This is text three")
#' (dfm1 <- dfm(txts[1:2]))
#' (dfm2 <- dfm(txts[2:3]))
#' (dfm3 <- dfm_select(dfm1, dfm2, valuetype = "fixed", verbose = TRUE))
#' setequal(featnames(dfm2), featnames(dfm3))
#' 
dfm_select <- function(x, pattern = NULL, 
                       selection = c("keep", "remove"), 
                       valuetype = c("glob", "regex", "fixed"),
                       case_insensitive = TRUE,
                       min_nchar = 1L, max_nchar = 79L,
                       verbose = quanteda_options("verbose")) {
    UseMethod("dfm_select")
}

#' @export
dfm_select.default <-  function(x, pattern = NULL, 
                            selection = c("keep", "remove"), 
                            valuetype = c("glob", "regex", "fixed"),
                            case_insensitive = TRUE,
                            min_nchar = 1L, max_nchar = 79L,
                            verbose = quanteda_options("verbose")) {
    stop(friendly_class_undefined_message(class(x), "dfm_select"))
}

#' @export
dfm_select.dfm <-  function(x, pattern = NULL, 
                            selection = c("keep", "remove"), 
                            valuetype = c("glob", "regex", "fixed"),
                            case_insensitive = TRUE,
                            min_nchar = 1L, max_nchar = 79L,
                            verbose = quanteda_options("verbose")) {
    
    x <- as.dfm(x)
    selection <- match.arg(selection)
    valuetype <- match.arg(valuetype)
    attrs <- attributes(x)
    is_dfm <- FALSE
    padding <- FALSE
    
    # select features based on "pattern"
    features_keep <- seq_len(nfeat(x))
    if (!is.null(pattern)) {
        # special handling if pattern is a dfm
        if (is.dfm(pattern)) {
            is_dfm <- TRUE
            pattern <- featnames(pattern)
            valuetype <- "fixed"
            padding <- TRUE
            case_insensitive <- FALSE
        } else if (is.dictionary(pattern)) {
            pattern <- 
                stri_replace_all_fixed(unlist(pattern, use.names = FALSE), 
                                       ' ', 
                                       attr(x, 'concatenator'))
        }
        features_id <- unlist(regex2id(pattern, featnames(x), valuetype, 
                                       case_insensitive), use.names = FALSE)
        
        if (!is.null(features_id)) 
            features_id <- sort(features_id) # keep the original column order
    } else {
        if (selection == "keep") {
            features_id <- seq_len(nfeat(x))
        } else {
            features_id <- NULL
        }
    }
    
    if (selection == "keep") {
        features_keep <- features_id
    } else {
        features_keep <- setdiff(features_keep, features_id)
    }
    
    # select features based on feature length
    if (!padding) {
        features_keep <- intersect(features_keep, which(stri_length(featnames(x)) >= min_nchar & 
                                                        stri_length(featnames(x)) <= max_nchar))
    }
    
    if (!length(features_keep)) features_keep <- 0
    temp <- x[, features_keep]    

    if (valuetype == 'fixed' && padding) {
        temp <- pad_dfm(temp, pattern)
        temp <- reassign_slots(temp, x)
    }
    if (is_dfm) {
        result <- temp[, pattern] # sort features into original order
    } else {
        result <- temp
    }
    
    if (verbose) {
        message_select(selection, 
                       length(features_id), 0, nfeat(temp) - nfeat(x), 0)
    }
    attributes(x, FALSE) <- attrs
    return(result)
}

#' @rdname dfm_select
#' @param ... used only for passing arguments from \code{dfm_remove} or
#'   \code{dfm_keep} to \code{dfm_select}. Cannot include
#'   \code{selection}.
#' @export
#' @examples 
#' tmpdfm <- dfm(c("This is a document with lots of stopwords.",
#'                 "No if, and, or but about it: lots of stopwords."),
#'               verbose = FALSE)
#' tmpdfm
#' dfm_remove(tmpdfm, stopwords("english"))
dfm_remove <- function(x, ...) {
    if ("selection" %in% names(list(...))) {
        stop("dfm_remove cannot include selection argument")
    }
    dfm_select(x, ..., selection = "remove")
}

#' @rdname dfm_select
#' @export
dfm_keep <- function(x, ...) {
    if ("selection" %in% names(list(...))) {
        stop("dfm_keep cannot include selection argument")
    }
    dfm_select(x, ..., selection = "keep")
}
