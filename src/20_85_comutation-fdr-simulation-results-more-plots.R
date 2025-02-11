
GRAPHS_DIR <- "20_85_comutation-fdr-simulation-results-more-plots"
reset_graph_directory(GRAPHS_DIR)

source(file.path("src", "20_83_comutation-fdr-simulation-shared.R"))

theme_set(theme_bw(base_size = 7, base_family = "Arial"))

demo_g1_rate <- 0.2
demo_g2_rate <- 0.6
demo_num_tumor_samples <- 100

demo_params_results <- comutation_fdr_simulation_results %>%
  filter(num_tumor_samples == demo_num_tumor_samples) %>%
  filter(near(g1_rate, demo_g1_rate) & near(g2_rate, demo_g2_rate))

num_sims <- max(demo_params_results$simulation_idx)


simulation_grid_plot <- function(df, fill_col) {
  df %>%
    ggplot(aes(col_idx, row_idx)) +
    geom_tile(aes(fill = {{ fill_col }}), color = "grey70") +
    scale_x_continuous(expand = c(0, 0), breaks = c(1, seq(0, 100, 20))) +
    scale_y_continuous(expand = c(0, 0), breaks = seq(1, 10)) +
    coord_fixed(ratio = 3) +
    theme(
      axis.ticks = element_blank(),
      plot.title = element_text(hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5)
    ) +
    labs(
      x = NULL,
      y = NULL
    )
}

demo_colorbar <- guide_colorbar(
  barwidth = unit(3, "mm"),
  barheight = unit(20, "mm")
)

p_title <- glue("Results of {num_sims} simulations with lambdas: {demo_g1_rate} & {demo_g2_rate}")
p_subtitle <- glue("Each cell represents the odds ratio from an individual simulation
                   of {demo_num_tumor_samples} tumor samples.")
demo_or_grid_plot <- demo_params_results %>%
  make_rows_cols_idx(estimate, 100) %>%
  simulation_grid_plot(estimate) +
  scale_fill_gradient(low = "white", high = "red", guide = demo_colorbar) +
  labs(
    fill = "odds ratio",
    title = p_title,
    subtitle = p_subtitle
  )
ggsave_wrapper(
  demo_or_grid_plot,
  plot_path(GRAPHS_DIR, "demo_or-grid-plot.svg"),
  "small"
)


p_subtitle <- glue("Each cell represents the p-value from an individual simulation
                   of {demo_num_tumor_samples} tumor samples.")
demo_pval_grid_plot <- demo_params_results %>%
  make_rows_cols_idx(-p_value, 100) %>%
  simulation_grid_plot(p_value) +
  scale_fill_gradient(low = "blue", high = "white", guide = demo_colorbar) +
  labs(
    fill = "p-value",
    title = p_title,
    subtitle = p_subtitle
  )
ggsave_wrapper(
  demo_pval_grid_plot,
  plot_path(GRAPHS_DIR, "demo_pval-grid-plot.svg"),
  "small"
)

p_subtitle <- glue("Each cell represents the if an individual simulation of {demo_num_tumor_samples} tumor samples
                   would result in a false positive")
demo_falsepos_grid_plot <- demo_params_results %>%
  make_rows_cols_idx(-p_value, 100) %>%
  mutate(is_proj_sig = map2_lgl(
    mutation_table, p_value,
    project_significance_check
  )) %>%
  simulation_grid_plot(is_proj_sig) +
  scale_fill_manual(
    values = c("white", "black"),
    labels = c(" true negative", "false positive")
  ) +
  theme(legend.key.size = unit(3, "mm")) +
  labs(
    x = NULL,
    y = NULL,
    fill = NULL,
    title = p_title,
    subtitle = p_subtitle
  )
ggsave_wrapper(
  demo_falsepos_grid_plot,
  plot_path(GRAPHS_DIR, "demo_falsepos-grid-plot.svg"),
  "small"
)


odds_ratio_denisty <- demo_params_results %>%
  ggplot(aes(x = estimate)) +
  geom_density() +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.02))) +
  theme(
    plot.title = element_text(hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5)
  ) +
  labs(
    x = "odds ratio of simulation",
    y = "density",
    title = "Distribution of odds ratios from 1000 simulations",
    subtitle = glue("Simulation of {demo_num_tumor_samples} tumor samples and lambdas of {demo_g1_rate} and {demo_g2_rate}.")
  )
ggsave_wrapper(
  odds_ratio_denisty,
  plot_path(GRAPHS_DIR, "demo_odds-ratio-denisty.svg"),
  "small"
)

pvalue_denisty <- demo_params_results %>%
  ggplot(aes(x = p_value)) +
  geom_density() +
  geom_vline(xintercept = 0.01, color = "blue", lty = 2) +
  annotate("text",
    x = 0.04, y = 1.1,
    label = "p-value = 0.01", hjust = 0,
    color = "blue", family = "Arial", size = 3
  ) +
  scale_x_continuous(expand = c(0, 0), limits = c(0, 1.0)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.02))) +
  theme(
    plot.title = element_text(hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5)
  ) +
  labs(
    x = "p-value of simulation",
    y = "density",
    title = "Distribution of p-values from 1000 simulations",
    subtitle = glue("Simulation of {demo_num_tumor_samples} tumor samples and lambdas of {demo_g1_rate} and {demo_g2_rate}.")
  )
ggsave_wrapper(
  pvalue_denisty,
  plot_path(GRAPHS_DIR, "demo_pvalue-denisty.svg"),
  "small"
)

odds_pval_patch <- odds_ratio_denisty | pvalue_denisty
ggsave_wrapper(odds_pval_patch,
  plot_path(GRAPHS_DIR, "demo_odds-pval-patch.svg"),
  width = 6, height = 3
)


oddsratio_denisty_plt <- comutation_fdr_simulation_results %>%
  filter(near(g1_rate, demo_g1_rate) & near(g2_rate, demo_g2_rate)) %>%
  mutate(grp = fct_reorder(
    as.character(num_tumor_samples),
    num_tumor_samples
  )) %>%
  ggplot(aes(x = estimate)) +
  geom_density(aes(group = grp, color = num_tumor_samples)) +
  geom_vline(xintercept = 1, size = 0.4, color = "grey25") +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.02))) +
  scale_color_distiller(type = "div", palette = "PRGn") +
  theme(
    legend.position = c(0.85, 0.15),
    plot.title = element_text(hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5),
    legend.key.size = unit(3, "mm"),
    legend.background = element_blank()
  ) +
  labs(
    x = "odds ratio of simulation",
    y = "density",
    color = "number of simulation\ntumor samples",
    title = "Distribution of simulations with different numbers of tumor samples",
    subtitle = glue("Results of simulations with lambdas {demo_g1_rate} and {demo_g2_rate}.")
  )
ggsave_wrapper(
  oddsratio_denisty_plt,
  plot_path(GRAPHS_DIR, "sim_oddsratio-density-tumorsamples.svg"),
  "small"
)

oddsratio_summary_scatter <- comutation_fdr_simulation_results %>%
  filter(near(g1_rate, demo_g1_rate) & near(g2_rate, demo_g2_rate)) %>%
  group_by(num_tumor_samples) %>%
  summarise(
    avg_odds_ratio = median(estimate),
    sd_odds_ratio = sd(estimate, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  mutate(
    or_upper = avg_odds_ratio + sd_odds_ratio,
    or_lower = avg_odds_ratio - sd_odds_ratio
  ) %>%
  ggplot(aes(x = num_tumor_samples, y = avg_odds_ratio)) +
  geom_point() +
  geom_hline(yintercept = 1, size = 0.5, color = "grey25") +
  geom_linerange(aes(ymin = avg_odds_ratio),
    size = 0.4, ymax = 1, color = "blue", alpha = 0.5
  ) +
  theme(plot.background = element_rect(fill = "white", color = "black")) +
  labs(
    x = "number of tumor samples",
    y = "avg. odds ratio"
  )


oddsratio_patch_layout <- c(
  area(t = 1, l = 1, b = 10, r = 10),
  area(t = 2, l = 6, b = 5, r = 9)
)

oddsratio_patch <- (oddsratio_denisty_plt + oddsratio_summary_scatter) +
  plot_layout(design = oddsratio_patch_layout)
ggsave_wrapper(
  oddsratio_patch,
  plot_path(GRAPHS_DIR, "sim_oddsratio-tumorsamples_patch.svg"),
  "small"
)


comutation_fdr_summary <- comutation_fdr_simulation_results %>%
  mutate(
    is_proj_sig = map2_lgl(
      mutation_table, p_value,
      project_significance_check
    ),
    grp = paste(g1_rate, g2_rate, sep = "_")
  ) %>%
  group_by(grp, num_tumor_samples, g1_rate, g2_rate) %>%
  summarise(fdr = mean(is_proj_sig)) %>%
  ungroup() %>%
  mutate(max_mut_rate = map2_dbl(g1_rate, g2_rate, ~ max(.x, .y)))

comutation_fdr_trend <- comutation_fdr_summary %>%
  group_by(num_tumor_samples) %>%
  summarise(
    avg_fdr = mean(fdr),
    sd_fdr = sd(fdr)
  ) %>%
  ungroup()

comutation_fdr_lineplt <- comutation_fdr_summary %>%
  ggplot(aes(x = num_tumor_samples, y = fdr)) +
  geom_line(aes(color = max_mut_rate, group = grp),
    size = 0.5, alpha = 0.2
  ) +
  geom_line(aes(x = num_tumor_samples, y = avg_fdr),
    data = comutation_fdr_trend,
    size = 1, color = "black"
  ) +
  scale_color_gradient(low = "dodgerblue", high = "tomato") +
  scale_x_continuous(expand = expansion(mult = c(0, 0))) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.01))) +
  theme(
    plot.title = element_text(hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5)
  ) +
  labs(
    x = "number of tumor samples in simulation",
    y = "FDR",
    color = "max mutation rate",
    title = "False discovery rate as the number of tumor samples increases",
    subtitle = "Each line is a simulation using different rates of mutation for the genes."
  )
ggsave_wrapper(
  comutation_fdr_lineplt,
  plot_path(GRAPHS_DIR, "comutation-fdr-lineplt.svg"),
  "wide"
)



diff_rate_fdrs <- comutation_fdr_simulation_results %>%
  mutate(rate_diff = abs(round(g1_rate - g2_rate, 2))) %>%
  mutate(is_proj_sig = map2_lgl(
    mutation_table, p_value,
    project_significance_check
  )) %>%
  group_by(num_tumor_samples, rate_diff) %>%
  summarise(fdr = mean(is_proj_sig)) %>%
  ungroup()

diff_rate_fdrs_plot <- diff_rate_fdrs %>%
  ggplot(aes(x = rate_diff, y = fdr)) +
  geom_line(aes(group = num_tumor_samples, color = num_tumor_samples),
    alpha = 0.7
  ) +
  scale_color_gradient(low = "#3db85d", high = "#b83db4") +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.02))) +
  theme(plot.title = element_text(hjust = 0.5)) +
  labs(
    x = "difference in rates of mutation of simulated genes",
    y = "average simulation FDR",
    color = "number of\ntumor samples\nin simulation",
    title = "FDR of simulations per difference\nin mutation rate of the simulated genes"
  )
ggsave_wrapper(
  diff_rate_fdrs_plot,
  plot_path(GRAPHS_DIR, "diff-rates-fdr.svg"),
  "small"
)



obs_vs_known_mutation_rates <- comutation_fdr_simulation_results %>%
  mutate(
    g1_obs_rate = map_dbl(mutation_table, ~ sum(.x[2, ]) / sum(.x)),
    g2_obs_rate = map_dbl(mutation_table, ~ sum(.x[, 2]) / sum(.x))
  ) %>%
  mutate(
    g1_diff = (g1_rate - g1_obs_rate) / g1_rate,
    g2_diff = (g2_rate - g2_obs_rate) / g1_rate
  )

obs_vs_known_mutation_rates_plot <- obs_vs_known_mutation_rates %>%
  select(num_tumor_samples, g1_diff, g2_diff) %>%
  pivot_longer(-num_tumor_samples) %>%
  group_by(num_tumor_samples) %>%
  sample_frac(0.2) %>%
  filter(!is.na(value)) %>%
  ggplot(aes(x = num_tumor_samples, y = value, group = num_tumor_samples)) +
  geom_boxplot(aes(fill = num_tumor_samples), outlier.shape = NA) +
  scale_fill_gradient(low = "aquamarine2", high = "forestgreen") +
  scale_x_continuous(expand = expansion(mult = 0.02, 0.02)) +
  scale_y_continuous(limits = c(-0.4, 0.7)) +
  theme(legend.position = "none") +
  labs(
    x = "number of tumor samples",
    y = "standardized difference in observed and simulated mutation rate"
  )
ggsave_wrapper(
  obs_vs_known_mutation_rates_plot,
  plot_path(GRAPHS_DIR, "obs-vs-known-diff-rates.svg"),
  "wide"
)
