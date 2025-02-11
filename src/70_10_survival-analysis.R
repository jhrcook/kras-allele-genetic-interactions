# Survival analysis

library(survminer)
library(survival)


GRAPHS_DIR <- "70_10_survival-analysis"
reset_graph_directory(GRAPHS_DIR)
reset_table_directory(GRAPHS_DIR)



#### ---- Prepare TCGA survival data ---- ####

# KRAS information for all cancer samples.
tumor_sample_data <- cancer_full_muts_df %>%
  group_by(cancer, tumor_sample_barcode) %>%
  slice(1) %>%
  ungroup() %>%
  select(cancer, tumor_sample_barcode, ras_allele) %>%
  unique() %>%
  arrange(cancer) %>%
  mutate(
    kras_allele = str_remove(ras_allele, "KRAS_"),
    kras_mut = as.numeric(ras_allele != "WT")
  ) %>%
  select(cancer, tumor_sample_barcode, kras_mut, kras_allele)


# Parse the tumor stage to a numeric.
parse_tumor_stage <- function(x) {
  case_when(
    str_detect(x, "X") ~ NA_character_,
    x == "TIS" ~ "0",
    TRUE ~ str_remove_all(x, "[:alpha:]")
  ) %>%
    as.numeric()
}


# TCGA survival data with KRAS annotation.
tcga_survival_data_anno <- inner_join(
  tcga_survival_data,
  tumor_sample_data,
  by = c("cancer" = "cancer", "patient_id" = "tumor_sample_barcode")
) %>%
  filter(!is.na(os_months) & !is.na(os_status)) %>%
  mutate(
    time = os_months,
    status = as.numeric(os_status == "DECEASED"),
    sex = ifelse(sex == "Male", "M", "F"),
    path_t_stage = parse_tumor_stage(path_t_stage),
    path_m_stage = parse_tumor_stage(path_m_stage)
  )


#### ---- Prepare MMRF survival data ---- ####

mmrf_survival_data_anno <- inner_join(
  mmrf_survival_data,
  tumor_sample_data,
  by = c("cancer" = "cancer", "public_id" = "tumor_sample_barcode")
) %>%
  select(
    cancer, public_id, age, sex,
    kras_mut, kras_allele, iss_disease_stage,
    date_of_death, time_to_os, censor_flag_overall_survival,
    overall_survival_censored_date, time_to_os_event_censored
  ) %>%
  mutate(
    time = overall_survival_censored_date,
    status = as.numeric(censor_flag_overall_survival)
  )


#### ---- Combined survival data ---- ####

# Merged survival data.
# Note that a lot of features will be all `NA` for MM.
# Some may be in the original data and can be retrieved during munging.
cancer_survival_df <- bind_rows(
  {
    tcga_survival_data_anno %>%
      dplyr::rename(tumor_sample_barcode = patient_id) %>%
      mutate(
        path_t_stage = parse_tumor_stage(path_t_stage),
        path_m_stage = parse_tumor_stage(path_m_stage)
      ) %>%
      select(
        cancer, tumor_sample_barcode,
        age, sex, weight, ethnicity,
        path_t_stage, path_m_stage,
        kras_mut, kras_allele,
        time, status
      )
  },
  {
    mmrf_survival_data_anno %>%
      dplyr::rename(
        tumor_sample_barcode = public_id,
        path_t_stage = iss_disease_stage
      ) %>%
      select(
        cancer, tumor_sample_barcode,
        age, sex,
        path_t_stage,
        kras_mut, kras_allele,
        time, status
      )
  }
)

cache(
  "cancer_survival_df",
  depends = c(
    "mmrf_survival_data",
    "tcga_survival_data",
    "cancer_full_muts_df"
  )
)


# Save ggproto objects for use in figures.
save_ggproto_for_figures <- function(p, cancer, sname) {
  save_cancers <- c("LUAD")

  if (cancer %in% save_cancers) {
    saveFigRds(p, sname)
  }
}


#### ---- Overall survival curves ---- ####

# A wrapper for `ggsurvplot()` for this section of the analysis.
ggsurv_wrapper_overallsa <- function(fit, data, plt_sname,
                                     tbl_col = "strata",
                                     pal = NULL) {
  p <- ggsurvplot(
    fit = fit,
    data = data,
    conf.int = TRUE,
    risk.table = TRUE,
    risk.table.col = "strata",
    surv.median.line = "hv",
    fontsize = 3,
    font.family = "arial",
    palette = pal
  )
  p <- style_ggsurvminer_plot(p)
  surv_plot <- patch_ggsurvplot(p)
  ggsave_wrapper(
    surv_plot,
    plot_path(GRAPHS_DIR, glue(plt_sname)),
    "wide"
  )
}


# A model of all cancers compared to each other.
all_cancer_survival_model <- function(data) {
  fit <- survfit(Surv(time = time, event = status) ~ cancer, data = data)

  write_survfit_summary(fit, "All cancers survival model",
    "all_cancer_model.txt",
    clear_file = TRUE
  )

  ggsurv_wrapper_overallsa(fit, data,
    "allcancers_survival.svg",
    pal = unname(cancer_palette)
  )
}


# Survival curve for a cancer.
cancer_survival_model <- function(cancer, data) {
  fit <- survfit(Surv(time = time, event = status) ~ 1, data = data)

  write_survfit_summary(
    fit, glue("{cancer} survival model"),
    "cancer_models.txt"
  )

  ggsurv_wrapper_overallsa(fit, data, glue("survival_{cancer}.svg"),
    pal = cancer_palette[[cancer]]
  )
}


# Separate sexes in each cancer.
cancer_sex_survival_model <- function(cancer, data, formula) {
  data %<>% filter(!is.na(sex))

  fit <- survfit(Surv(time = time, event = status) ~ sex, data = data)
  coxph_fit <- coxph(Surv(time = time, event = status) ~ sex, data = data)

  title <- glue("{cancer} survival model by sex")
  fname <- "cancer_sex_models.txt"
  write_survfit_summary(fit, title, fname)
  write_coxph_summary(coxph_fit, title, fname)

  pal <- c("tomato", "dodgerblue")

  ggsurv_wrapper_overallsa(
    fit, data,
    plt_sname = glue("sex_survival_{cancer}.svg"),
    tbl_col = "sex",
    pal = pal
  )

  p <- ggadjustedcurves(
    fit = coxph_fit,
    variable = "sex",
    data = as.data.frame(data),
    palette = pal
  ) +
    ggtitle(glue("{cancer} (adjusted curve)"))
  p <- style_ggsurvminer_surv_curve(p, x_expand = c(0, 0.02))
  ggsave_wrapper(
    p,
    plot_path(GRAPHS_DIR, glue("sex-adjusted_survival_{cancer}.svg")),
    "wide"
  )
}


cancer_survival_df %T>%
  all_cancer_survival_model() %>%
  group_by(cancer) %>%
  nest() %>%
  arrange(cancer) %T>%
  pwalk(cancer_survival_model) %T>%
  pwalk(cancer_sex_survival_model)



#### ---- KRAS allele survival curves ---- ####


# Get the alleles with more than `other_min` samples.
get_alleles_to_keep <- function(df, other_min) {
  df %>%
    group_by(kras_allele) %>%
    summarise(num_allele_samples = n_distinct(tumor_sample_barcode)) %>%
    ungroup() %>%
    filter(num_allele_samples > !!other_min) %>%
    pull(kras_allele)
}


# Group the KRAS alleles into "Other" if fewer than `other_min` samples.
group_kras_alleles <- function(df, other_min) {
  alleles_to_keep <- get_alleles_to_keep(df, other_min)
  df %>%
    mutate(kras_allele_grp = case_when(
      kras_allele == "WT" ~ "WT",
      kras_allele %in% !!alleles_to_keep ~ kras_allele,
      TRUE ~ "Other"
    ))
}


# Wrapper around standard survial curve analysis workflow.
allele_group_survival_analysis <- function(cancer,
                                           data,
                                           do_survdiff = TRUE,
                                           do_coxph = TRUE,
                                           p_val_sig = NULL,
                                           model_output_file_template = NULL,
                                           model_output_title_template = NULL,
                                           plot_name_template = NULL,
                                           curve_palette = NULL,
                                           plot_file_size = "wide",
                                           save_proto = FALSE) {
  title <- glue(model_output_title_template)
  fname <- glue(model_output_file_template)

  write_out <- (
    !is.null(model_output_file_template) &
      !is.null(model_output_title_template)
  )

  fit <- survfit(Surv(time = time, event = status) ~ kras_allele_grp,
    data = data
  )
  if (write_out) write_survfit_summary(fit, title, fname)

  if (do_survdiff) {
    fit_diff <- survdiff(
      Surv(time = time, event = status) ~ kras_allele_grp,
      data = data
    )
    if (write_out) write_survdiff_summary(fit_diff, title, fname)
  }

  if (do_coxph) {
    fit_coxph <- coxph(
      Surv(time = time, event = status) ~ kras_allele_grp,
      data = data
    )
    if (write_out) write_coxph_summary(fit_coxph, title, fname)
  }

  # If no name for saving plots, return early.
  if (is.null(plot_name_template)) {
    return()
  }

  # If using a cut-off, if the p-value is not low enough, return early.
  if (!is.null(p_val_sig) & do_survdiff) {
    if (survdiff_pval(fit_diff) >= p_val_sig) {
      return()
    }
  }

  p <- ggsurvplot(
    fit = fit,
    data = data,
    pval = TRUE,
    conf.int = FALSE,
    risk.table = TRUE,
    risk.table.col = "strata",
    surv.median.line = "hv",
    fontsize = 3,
    font.family = "arial",
    palette = curve_palette
  ) +
    ggtitle(cancer)
  p <- style_ggsurvminer_plot(p)
  surv_plot <- patch_ggsurvplot(p)
  ggsave_wrapper(
    surv_plot,
    plot_path(GRAPHS_DIR, glue(plot_name_template)),
    plot_file_size
  )

  if (save_proto) {
    fig_p <- ggsurvplot(
      fit = fit,
      data = data,
      pval = FALSE,
      conf.int = FALSE,
      risk.table = TRUE,
      risk.table.col = "strata",
      surv.median.line = "none",
      fontsize = 2,
      censor.size = 2,
      size = 0.5,
      font.family = "arial",
      palette = curve_palette
    ) +
      ggtitle(cancer)
    save_ggproto_for_figures(
      fig_p, cancer,
      as.character(glue(plot_name_template))
    )
  }
}


# Survival analysis of KRAS mutant vs WT.
kras_mutated_survival_analysis <- function(cancer, data) {
  data <- data %>%
    mutate(kras_allele_grp = ifelse(kras_mut == 0, "WT", "mut"))

  pal <- alter_pal_for_ggsurvplot(
    c(WT = "grey50", mut = "black"),
    "kras_allele_grp"
  )

  allele_group_survival_analysis(
    cancer = cancer,
    data = data,
    do_survdiff = TRUE,
    do_coxph = TRUE,
    model_output_file_template = "wt-vs-krasmut.txt",
    model_output_title_template = glue("{cancer} KRAS WT vs. mutant"),
    plot_name_template = glue("krasmut_survival_{cancer}.svg"),
    curve_palette = pal,
    save_proto = TRUE
  )
}


# KRAS mutated and sex as covariates in the survival analysis.
cancer_sex_krasmut_survival_model <- function(cancer, data, formula) {
  data %<>% filter(!is.na(sex))

  fit <- survfit(Surv(time = time, event = status) ~ sex + kras_mut,
    data = data
  )
  coxph_fit <- coxph(Surv(time = time, event = status) ~ sex + kras_mut,
    data = data
  )

  title <- glue("{cancer} survival model by sex & KRAS mut")
  fname <- "sex-krasmut_models.txt"
  write_survfit_summary(fit, title, fname)
  write_coxph_summary(coxph_fit, title, fname)

  pal <- c("palevioletred1", "tomato", "lightskyblue", "dodgerblue")

  p <- ggsurvplot(
    fit = fit,
    data = data,
    conf.int = TRUE,
    risk.table = TRUE,
    risk.table.col = "sex",
    surv.median.line = "hv",
    fontsize = 3,
    font.family = "arial",
    palette = pal
  ) +
    ggtitle(cancer)
  p <- style_ggsurvminer_plot(p)
  surv_plot <- patch_ggsurvplot(p)
  ggsave_wrapper(
    surv_plot,
    plot_path(GRAPHS_DIR, glue("sex-krasmut_survival_{cancer}.svg")),
    "wide"
  )
}


# Survival curve for a cancer's data separated by KRAS alleles.
kras_alleles_survival_analysis <- function(cancer, data, other_min = 10) {
  data <- group_kras_alleles(data, other_min)

  allele_group_survival_analysis(
    cancer = cancer,
    data = data,
    do_survdiff = TRUE,
    do_coxph = TRUE,
    model_output_file_template = "kras-alleles.txt",
    model_output_title_template = glue("{cancer} KRAS alleles"),
    plot_name_template = glue("krasallele_survival_{cancer}.svg"),
    curve_palette = alter_pal_for_ggsurvplot(
      short_allele_pal,
      "kras_allele_grp"
    ),
    save_proto = TRUE
  )
}


# KRAS allele vs. rest of the samples.
kras_allele_vs_rest_survival_analysis <- function(cancer, data,
                                                  other_min = 10) {
  data <- group_kras_alleles(data, other_min)
  all_alleles <- unique(data$kras_allele_grp)

  pal <- alter_pal_for_ggsurvplot(
    c(short_allele_pal, "rest" = "grey40"),
    "kras_allele_grp"
  )

  for (allele in all_alleles[!all_alleles %in% c("WT", "Other")]) {
    mod_data <- data %>%
      mutate(kras_allele_grp = ifelse(kras_allele_grp == allele,
        allele, "rest"
      ))

    filename <- glue("{cancer}_{allele}-vs-rest.txt")
    title <- glue("{cancer} - {allele} vs. the rest")
    plot_sname <- glue("allele-vs-rest_{cancer}_{allele}.svg")

    allele_group_survival_analysis(
      cancer = cancer,
      data = mod_data,
      do_survdiff = TRUE,
      do_coxph = FALSE,
      model_output_file_template = filename,
      model_output_title_template = title,
      plot_name_template = plot_sname,
      curve_palette = pal
    )
  }
}


# All combinations of `x` in sets of `m`.
allele_combination_tibble <- function(x, m = 2) {
  combn(x, m, stringsAsFactors = FALSE) %>%
    t() %>%
    as.data.frame() %>%
    as_tibble() %>%
    dplyr::rename(allele_1 = V1, allele_2 = V2)
}


# Every combinations of KRAS allele vs KRAS allele.
kras_allele_vs_each_allele_survival_analysis <- function(cancer, data,
                                                         other_min = 10,
                                                         p_val_sig = 0.1) {
  data <- group_kras_alleles(data, other_min)
  all_alleles <- unique(data$kras_allele_grp)

  pal <- alter_pal_for_ggsurvplot(short_allele_pal, "kras_allele_grp")

  allele_combs <- allele_combination_tibble(all_alleles) %>%
    filter(allele_1 != "Other" & allele_2 != "Other")

  for (i in seq(1, nrow(allele_combs))) {
    allele_1 <- allele_combs$allele_1[[i]]
    allele_2 <- allele_combs$allele_2[[i]]
    mod_data <- data %>%
      filter(kras_allele_grp %in% c(allele_1, allele_2))

    filename <- glue("{cancer}_allele-vs-allele.txt")
    title <- glue("{cancer} - {allele_1} vs. {allele_2}")
    plot_title <- glue(
      "{allele_1}-vs-{allele_2}_{cancer}.svg"
    )

    allele_group_survival_analysis(
      cancer = cancer,
      data = mod_data,
      do_survdiff = TRUE,
      do_coxph = FALSE,
      p_val_sig = p_val_sig,
      model_output_file_template = filename,
      model_output_title_template = title,
      plot_name_template = plot_title,
      curve_palette = pal,
      save_proto = TRUE
    )
  }
}


cancer_survival_df %>%
  group_by(cancer) %>%
  nest() %>%
  arrange(cancer) %T>%
  pwalk(kras_mutated_survival_analysis) %T>%
  pwalk(cancer_sex_krasmut_survival_model) %T>%
  pwalk(kras_alleles_survival_analysis) %T>%
  pwalk(kras_allele_vs_rest_survival_analysis) %T>%
  pwalk(kras_allele_vs_each_allele_survival_analysis)



#### ---- Tumor stage ---- ####


# A wrapper around `ggsurvplot()`.
ggsurvplot_wrapper <- function(fit, data, save_name_template,
                               tbl_col = NULL, facet_formula = NULL,
                               pal = NULL, plt_title = NULL,
                               save_size = "wide") {
  p <- ggsurvplot(
    fit = fit,
    data = data,
    conf.int = TRUE,
    risk.table = TRUE,
    risk.table.col = tbl_col,
    surv.median.line = "hv",
    fontsize = 3,
    font.family = "arial",
    palette = pal
  ) +
    ggtitle(plt_title)
  p <- style_ggsurvminer_plot(p)

  if (!is.null(facet_formula)) {
    p$plot <- p$plot + facet_grid(facet_formula)
  }

  surv_plot <- patch_ggsurvplot(p)
  ggsave_wrapper(
    surv_plot,
    plot_path(GRAPHS_DIR, glue(save_name_template)),
    save_size
  )
}


# Survival analysis with tumor stage as covariate.
tumorstage_sa <- function(cancer, data) {
  # Fit survival curve and Cox PH
  fit <- survfit(Surv(time = time, event = status) ~ path_t_stage,
    data = data
  )
  fit_coxph <- coxph(Surv(time = time, event = status) ~ path_t_stage,
    data = data
  )

  # Write survival curve and Cox PH
  title <- glue("{cancer} survival model by tumor stage")
  fname <- "tumorstage_models.txt"
  write_survfit_summary(fit, title, fname)
  write_coxph_summary(fit_coxph, title, fname)

  # Plot survival curve
  pal <- viridis::viridis_pal()(n_distinct(data$path_t_stage))
  ggsurvplot_wrapper(fit,
    data,
    glue("tumorstage_survival_{cancer}.svg"),
    tbl_col = "path_t_stage",
    pal = pal,
    plt_title = cancer
  )
}


# Survival analysis with tumor stage and sex as covariates.
tumorstage_sex_sa <- function(cancer, data) {
  # Fit survival curve and Cox PH
  fit <- survfit(Surv(time = time, event = status) ~ path_t_stage + sex,
    data = data
  )
  fit_coxph <- coxph(Surv(time = time, event = status) ~ path_t_stage + sex,
    data = data
  )

  # Write survival curve and Cox PH
  title <- glue("{cancer} survival model by tumor stage & sex")
  fname <- "tumorstage-sex_models.txt"
  write_survfit_summary(fit, title, fname)
  write_coxph_summary(fit_coxph, title, fname)

  # Plot survival curve
  pal <- NULL
  save_name <- glue("tumorstage-sex_survival_{cancer}.svg")
  ggsurvplot_wrapper(fit,
    data,
    save_name,
    tbl_col = "sex",
    facet_formula = path_t_stage ~ .,
    pal = pal,
    plt_title = cancer,
    save_size = "large"
  )
}


# Survival analysis with tumor stage and KRAS mutated as covariates.
tumorstage_krasmut_sa <- function(cancer, data) {
  # Fit survival curve and Cox PH
  fit <- survfit(
    Surv(time = time, event = status) ~ kras_mut + path_t_stage,
    data = data
  )
  fit_coxph <- coxph(
    Surv(time = time, event = status) ~ kras_mut + path_t_stage,
    data = data
  )

  # Write survival curve and Cox PH
  title <- glue("{cancer} survival model by tumor stage & KRAS mutation")
  fname <- "tumorstage-krasmut_models.txt"
  write_survfit_summary(fit, title, fname)
  write_coxph_summary(fit_coxph, title, fname)

  # Plot survival curve
  pal <- NULL
  save_name <- glue("tumorstage-krasmut_survival_{cancer}.svg")
  ggsurvplot_wrapper(fit,
    data,
    save_name,
    tbl_col = "kras_mut",
    facet_formula = path_t_stage ~ .,
    pal = pal,
    plt_title = cancer,
    save_size = "large"
  )
}


# Survival analysis of samples of a tumor stage with KRAS mutated as covariates.
krasmut_pertumorstage_sa <- function(cancer, path_t_stage, data) {
  # fit <- survfit(Surv(time = time, event = status) ~ kras_mut,
  #                data = data)
  fit_diff <- survdiff(Surv(time = time, event = status) ~ kras_mut,
    data = data
  )

  fname <- glue("krasmut_pertstage_{cancer}.txt")
  title <- glue("{cancer} - Stage T{path_t_stage} - KRAS mutant vs. WT")
  write_survdiff_summary(fit_diff, title = title, fname = fname)
}


cancer_survival_df %>%
  filter(!is.na(path_t_stage) & path_t_stage > 0) %>%
  mutate(path_t_stage = factor(path_t_stage)) %>%
  group_by(cancer) %>%
  nest() %>%
  arrange(cancer) %T>%
  pwalk(tumorstage_sa) %T>%
  pwalk(tumorstage_sex_sa) %T>%
  pwalk(tumorstage_krasmut_sa) %>%
  unnest(data) %>%
  group_by(cancer, path_t_stage) %>%
  nest() %>%
  arrange(cancer, path_t_stage) %T>%
  pwalk(krasmut_pertumorstage_sa)
