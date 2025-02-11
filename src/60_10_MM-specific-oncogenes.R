# Because of the sparse comutation network found for MM, I decided to look
# into the interactions with known oncogenes.

GRAPHS_DIR <- "60_10_MM-specific-oncogenes"
reset_graph_directory(GRAPHS_DIR)

# List of known oncogenes in MM
mm_oncogenes <- unique(c(
  cancer_oncogenes$MM,
  get_cgc_genes("MM")
))
mm_oncogenes <- mm_oncogenes[mm_oncogenes != "KRAS"]



#### ---- Comutation frequencies ---- ####

# MM mutation data.
mm_mut_df <- cancer_coding_muts_df %>%
  filter(cancer == "MM") %>%
  filter(hugo_symbol %in% !!mm_oncogenes) %>%
  mutate(allele = str_remove_all(ras_allele, "KRAS_"))

num_mm_tumor_samples <- cancer_coding_muts_df %>%
  filter(cancer == "MM") %>%
  pull(tumor_sample_barcode) %>%
  n_distinct()
print(glue("number of MM tumor samples: {num_mm_tumor_samples}"))

# Number of samples per KRAS allele.
cancer_allele_count_df <- cancer_coding_muts_df %>%
  filter(cancer == "MM") %>%
  mutate(
    allele = str_remove_all(ras_allele, "KRAS_"),
    num_tumor_samples = n_distinct(tumor_sample_barcode)
  ) %>%
  group_by(allele, num_tumor_samples) %>%
  summarise(num_allele_samples = n_distinct(tumor_sample_barcode)) %>%
  ungroup() %>%
  arrange(-num_allele_samples)

# KRAS allele comutation data.
mm_comut_df <- mm_mut_df %>%
  group_by(hugo_symbol, allele) %>%
  summarise(num_allele_comuts = n_distinct(tumor_sample_barcode)) %>%
  ungroup() %>%
  tidyr::complete(hugo_symbol, allele, fill = list(num_allele_comuts = 0)) %>%
  left_join(cancer_allele_count_df, by = "allele") %>%
  mutate(freq_allele_comuts = num_allele_comuts / num_allele_samples)

# Statistically significant interactions.
sig_interactions <- genetic_interaction_df %>%
  filter(cancer == "MM") %>%
  filter(hugo_symbol %in% !!mm_oncogenes) %>%
  select(hugo_symbol, allele, p_val, genetic_interaction) %>%
  mutate(genetic_interaction = switch_comut_terms(genetic_interaction))

mm_comut_df %<>%
  left_join(sig_interactions, by = c("hugo_symbol", "allele"))



#### ---- Heatmap of comutation frequency ---- ####

MIN_NUM_ALLELE_SAMPLES <- 10

mut_freq_order <- mm_mut_df %>%
  group_by(hugo_symbol) %>%
  summarise(n = n_distinct(tumor_sample_barcode)) %>%
  ungroup() %>%
  arrange(n) %>%
  pull(hugo_symbol)


make_mm_comut_heatmap <- function(df) {
  df %>%
    mutate(
      allele = factor_alleles(allele),
      hugo_symbol = factor(hugo_symbol, levels = mut_freq_order),
      label = round(freq_allele_comuts, 3) * 100,
      label = case_when(
        !is.na(genetic_interaction) ~ as.character(label),
        label > 0 ~ as.character(label),
        label == 0 ~ "-"
      ),
      label_face = ifelse(!is.na(genetic_interaction), "bold", "plain")
    ) %>%
    ggplot(aes(x = allele, y = hugo_symbol)) +
    geom_tile(
      aes(fill = freq_allele_comuts),
      color = "grey20"
    ) +
    geom_text(
      aes(
        label = label,
        fontface = label_face
      ),
      family = "Arial",
      size = 2.5
    ) +
    scale_fill_gradient2(
      low = "dodgerblue",
      high = "tomato",
      mid = "grey90",
      midpoint = 0.10
    ) +
    scale_x_discrete(expand = c(0, 0)) +
    scale_y_discrete(expand = c(0, 0)) +
    theme_bw(base_size = 7, base_family = "Arial") +
    theme(
      axis.title = element_blank(),
      axis.ticks = element_blank(),
      legend.position = "bottom"
    ) +
    labs(
      fill = "comutation frequency"
    )
}

mm_comut_heatmap <- mm_comut_df %>%
  filter(num_allele_samples > !!MIN_NUM_ALLELE_SAMPLES) %>%
  make_mm_comut_heatmap()

ggsave_wrapper(
  mm_comut_heatmap,
  plot_path(GRAPHS_DIR, "mm_comut_heatmap.svg"),
  "medium"
)


make_allele_freq_barplot <- function(df) {
  df %>%
    mutate(allele = factor_alleles(allele)) %>%
    ggplot(aes(x = allele, y = num_allele_samples)) +
    geom_col(fill = "grey75") +
    scale_y_continuous(
      breaks = c(5, 10, 50, 200, 500),
      expand = expansion(mult = c(0, 0.05)),
      trans = my_trans_log10
    ) +
    scale_x_discrete(expand = c(0, 0)) +
    theme_bw(base_family = "Arial", base_size = 7) +
    theme(
      axis.title.x = element_blank(),
      axis.text.x = element_blank(),
      axis.ticks = element_blank()
    ) +
    labs(y = "num. tumor\nsamples")
}

allele_freq_barplot <- cancer_allele_count_df %>%
  filter(num_allele_samples > !!MIN_NUM_ALLELE_SAMPLES) %>%
  make_allele_freq_barplot()


make_gene_freq_barplot <- function(df) {
  df %>%
    mutate(hugo_symbol = fct_reorder(hugo_symbol, n)) %>%
    ggplot(aes(x = hugo_symbol, y = n)) +
    geom_col(fill = "grey75") +
    coord_flip() +
    scale_y_continuous(
      expand = expansion(mult = c(0, 0.05))
    ) +
    scale_x_discrete(expand = c(0, 0)) +
    theme_bw(base_family = "Arial", base_size = 7) +
    theme(
      axis.title.y = element_blank(),
      axis.text.y = element_blank(),
      axis.ticks = element_blank(),
      axis.text.x = element_text(angle = 270, hjust = 0)
    ) +
    labs(y = "num. mutant\nsamples")
}


gene_freq_barplot <- mm_mut_df %>%
  group_by(hugo_symbol) %>%
  summarise(n = n_distinct(tumor_sample_barcode)) %>%
  ungroup() %>%
  make_gene_freq_barplot()

patch <-
  (allele_freq_barplot + plot_spacer() + plot_layout(widths = c(10, 2))) /
  (mm_comut_heatmap + gene_freq_barplot + plot_layout(widths = c(10, 2))) +
  plot_layout(heights = c(2, 10))
ggsave_wrapper(
  patch,
  plot_path(GRAPHS_DIR, "margin_barplots_heatmap_patchwork.svg"),
  "medium"
)


saveFigRds(mm_comut_heatmap, "mm_comut_heatmap")
saveFigRds(allele_freq_barplot, "allele_freq_barplot")
saveFigRds(gene_freq_barplot, "gene_freq_barplot")



#### ---- A truncated version for figure ---- ####


truncated_mm_oncogenes <- tail(mut_freq_order,
  n = which(rev(mut_freq_order) == "TP53")
)

mm_comut_heatmap <- mm_comut_df %>%
  filter(num_allele_samples > !!MIN_NUM_ALLELE_SAMPLES) %>%
  filter(hugo_symbol %in% !!truncated_mm_oncogenes) %>%
  make_mm_comut_heatmap()

allele_freq_barplot <- cancer_allele_count_df %>%
  filter(num_allele_samples > !!MIN_NUM_ALLELE_SAMPLES) %>%
  make_allele_freq_barplot()

gene_freq_barplot <- mm_mut_df %>%
  filter(hugo_symbol %in% !!truncated_mm_oncogenes) %>%
  group_by(hugo_symbol) %>%
  summarise(n = n_distinct(tumor_sample_barcode)) %>%
  ungroup() %>%
  make_gene_freq_barplot()

patch <-
  (allele_freq_barplot + plot_spacer() + plot_layout(widths = c(10, 2))) /
  (mm_comut_heatmap + gene_freq_barplot + plot_layout(widths = c(10, 2))) +
  plot_layout(heights = c(2, 10))
ggsave_wrapper(
  patch,
  plot_path(GRAPHS_DIR, "margin_barplots_heatmap_patchwork_TRUNCATED.svg"),
  "medium"
)


saveFigRds(mm_comut_heatmap, "mm_comut_heatmap_TRUNCATED")
saveFigRds(allele_freq_barplot, "allele_freq_barplot_TRUNCATED")
saveFigRds(gene_freq_barplot, "gene_freq_barplot_TRUNCATED")
