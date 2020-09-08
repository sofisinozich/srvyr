#' @export
summarise.tbl_svy <- function(.data, ..., .groups = NULL, .unpack = TRUE) {
  .dots <- rlang::quos(...)
  if (is_lazy_svy(.data)) .data <- localize_lazy_svy(.data, .dots)

  # Set current_svy so available to svy stat functions
  old <- set_current_svy(list(full = .data, split = list(.data)))
  on.exit(set_current_svy(old), add = TRUE)

  out <- dplyr::summarise(.data$variables, ..., .groups = .groups)

  # srvyr predates dplyr's data.frame columns so default to unpacking
  # them wide
  if (.unpack) out <- unpack_cols(out)
  out
}

#' @export
summarise_.tbl_svy <- function(.data, ..., .dots) {
  dots <- compat_lazy_dots(.dots, caller_env(), ...)
  summarise(.data, !!!dots)
}

#' @export
summarise.grouped_svy <- function(.data, ..., .groups = NULL, .unpack = TRUE) {
  .dots <- rlang::quos(...)
  if (is_lazy_svy(.data)) .data <- localize_lazy_svy(.data, .dots)

  # Set current_svy so available to svy stat functions
  old <- set_current_svy(list(full = .data, split = group_split(.data)))
  on.exit(set_current_svy(old), add = TRUE)

  out <- dplyr::summarise(.data$variables, !!!.dots, .groups = .groups)

  # srvyr predates dplyr's data.frame columns so default to unpacking
  # them wide
  if (.unpack) out <- unpack_cols(out)
  out
}

unpack_cols <- function(results) {
  old_groups <- group_vars(results)
  out <- lapply(names(results), function(col_name) {
    col <- results[col_name]
    if (is.data.frame(col[[1]])) {
      col <- col[[1]]
      names(col) <- ifelse(names(col) == "__SRVYR_COEF__", col_name, paste0(col_name, names(col)))
    }
    col
  })
  out <- dplyr::bind_cols(out)
  if (length(old_groups) > 0) out <- group_by(out, !!!rlang::syms(old_groups))
  out
}

#' @export
summarise_.grouped_svy <- function(.data, ..., .dots) {
  dots <- compat_lazy_dots(.dots, caller_env(), ...)
  summarise(.data, !!!dots)
}

finalize_grouping <- function(x, .groups) {
  orig_groups <- group_vars(x)

  switch(
    .groups,
    "drop" = identity,
    "drop_last" = function(x) group_by_at(x, orig_groups[-length(orig_groups)]),
    "keep" = function(x) group_by_at(x, orig_groups),
    "rowwise" = dplyr::rowwise
  )
}

summarise_result_nrow_check <- function(results, names) {
  allowed_row_nums <- 1
  lapply(seq_along(results), function(iii) {
    res_name <- names[[iii]]
    cur_rows <- nrow(results[[iii]])
    if (!cur_rows %in% c(1, allowed_row_nums)) {
      if (allowed_row_nums != 1) {
        stop(paste0(
          "summarise results for argument `", res_name, "` must be size 1 or ",
          allowed_row_nums, " but it is ", cur_rows
        ))
      } else {
        allowed_row_nums <<- cur_rows
      }
    }
  })
}

#' Summarise multiple values to a single value.
#'
#' Summarise multiple values to a single value.
#'
#'
#' @param .data tbl A \code{tbl_svy} object
#' @param ... Name-value pairs of summary functions
#' @param .groups Defaults to "drop_last" in srvyr meaning that the last group is peeled
#' off, but if there are more groups they will be preserved. Other options are "drop", which
#' drops all groups, "keep" which keeps all of them and "rowwise" which converts the object
#' to a rowwise object (meaning calculations will be performed on each row).
#'
#' @details
#' Summarise for \code{tbl_svy} objects accepts several specialized functions.
#' Each of the functions a variable (or two, in the case of
#' \code{survey_ratio}), from the data.frame and default to providing the measure
#' and its standard error.
#'
#' The argument \code{vartype} can choose one or more measures of uncertainty,
#' \code{se} for standard error, \code{ci} for confidence interval, \code{var}
#' for variance, and \code{cv} for coefficient of variation. \code{level}
#' specifies the level for the confidence interval.
#'
#' The other arguments correspond to the analagous function arguments from the
#' survey package.
#'
#' The available functions from srvyr are:
#'
#'\describe{
#' \item{\code{\link{survey_mean}}}{
#'    Calculate the survey mean of the entire population or by \code{groups}.
#'    Based on \code{\link[survey]{svymean}}.}
#' \item{\code{\link{survey_total}}}{
#'    Calculate the survey total of the entire population or by \code{groups}.
#'    Based on \code{\link[survey]{svytotal}}.}
#'  \item{\code{\link{survey_ratio}}}{
#'    Calculate the ratio of 2 variables in the entire population or by \code{groups}.
#'    Based on \code{\link[survey]{svyratio}}.}
#' \item{\code{\link{survey_quantile}}}{
#'    Calculate quantiles in the entire population or by \code{groups}. Based on
#'    \code{\link[survey]{svyquantile}}.}
#'  \item{\code{\link{survey_median}}}{
#'    Calculate the median in the entire population or by \code{groups}.
#'    \code{\link[survey]{svyquantile}}.}
#'  \item{\code{\link{unweighted}}}{
#'    Calculate an unweighted estimate as you would on a regular \code{tbl_df}.
#'    Based on dplyr's \code{\link[dplyr]{summarise}}.}
#'}
#' @examples
#' library(survey)
#' data(api)
#'
#' dstrata <- apistrat %>%
#'   as_survey_design(strata = stype, weights = pw)
#'
#' dstrata %>%
#'   summarise(api99 = survey_mean(api99),
#'             api00 = survey_mean(api00),
#'             api_diff = survey_mean(api00 - api99))
#'
#' dstrata_grp <- dstrata %>%
#'   group_by(stype)
#'
#' dstrata_grp %>%
#'   summarise(api99 = survey_mean(api99),
#'             api00 = survey_mean(api00),
#'             api_diff = survey_mean(api00 - api99))
#'
#' @name summarise
#' @export
#' @importFrom dplyr summarise
NULL

#' @name summarise_
#' @export
#' @importFrom dplyr summarise_
#' @rdname srvyr-se-deprecated
#' @inheritParams summarise
NULL

#' @name summarize
#' @export
#' @importFrom dplyr summarize
#' @rdname summarise
NULL

#' @name summarize_
#' @export
#' @importFrom dplyr summarize_
#' @rdname srvyr-se-deprecated
#' @inheritParams summarize
NULL

