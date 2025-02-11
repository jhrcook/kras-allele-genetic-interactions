# Figure 042. #> Mutational signature main figure.
# (Based off of Fig 28.)

FIGNUM <- 42

# > SET THE FIGURE DIMENSIONS
FIG_DIMENSIONS <- get_figure_dimensions(2, "short")
FIG_DIMENSIONS$height <- 130

theme_fig42 <- function(tag_margin = margin(-1, -1, -1, -1, "mm")) {
  theme_comutation() %+replace%
    theme(
      legend.title = element_blank(),
      plot.tag = element_text(
        size = 7,
        face = "bold",
        margin = tag_margin
      )
    )
}



#### ---- A. Percent of samples with KRAS mutation ---- ####
# Percent of samples with a KRAS mutation per cancer.
# original script: "src/90_05_kras-allele-distribution.R"

panel_A <- read_fig_proto("cancer_freq_kras_mut_column") +
  scale_x_continuous(
    expand = expansion(add = c(0, 0.02)),
    breaks = c(0.2, 0.4, 0.6, 0.8),
    labels = function(x) {
      paste0(round(x * 100), "%")
    }
  ) +
  theme_fig42(tag_margin = margin(-1, -1, -1, -5.3, "mm")) +
  theme(
    axis.title.x = element_markdown(),
    axis.title.y = element_blank(),
    axis.text.x = element_text(hjust = 0.5, vjust = 1, angle = 0),
    legend.position = "none",
    panel.grid.major.y = element_blank()
  ) +
  labs(tag = "a")

pull_original_plot_data(panel_A) %>%
  select(-long_cancer) %>%
  save_figure_source_data(figure = FIGNUM, panel = "a")



#### ---- B. Distribution of KRAS alleles ---- ####
# The distribution of KRAS alleles across cancers and codon.
# original script: "src/90_05_kras-allele-distribution.R"

panel_B <- read_fig_proto("allele_dist_dotplot") +
  scale_size_continuous(labels = scales::label_percent(accuracy = 1)) +
  theme_fig42() +
  theme(
    axis.ticks = element_blank(),
    axis.title.x = element_markdown(),
    axis.title.y = element_blank(),
    axis.text.x = element_text(hjust = 0.5, vjust = 1, angle = 0),
    axis.text.y = element_blank(),
    legend.position = "right",
    legend.text = element_text(size = 6),
    legend.title = element_markdown(size = 6),
    legend.margin = margin(0, 0, 0, 0, "mm"),
    strip.background = element_blank(),
    strip.text = element_text(size = 7, vjust = -1)
  ) +
  labs(
    tag = "b",
    size = "percent of<br>*KRAS* mutations"
  )

pull_original_plot_data(panel_B) %>%
  select(-long_cancer) %>%
  mutate(codon = as.factor(codon)) %>%
  save_figure_source_data(figure = FIGNUM, panel = "b")


#### ---- C. Distirubiton of mutational signatures by allele ---- ####
# The distribution of mutational signature levels in samples with each allele.
# original script: "src/50_20_mutsignatures-distributions.R"

mutsig_barplot_widths <- c(7, 4, 5, 5)

style_mutsig_prob_barplots <- function(plt, i, tag = NULL, y = NULL) {
  themed_plt <- plt +
    scale_fill_manual(
      values = mutsig_descrpt_pal,
      guide = guide_legend(
        nrow = 1,
        title.position = "left",
        title.vjust = 0.2,
        label.position = "top",
        label.hjust = 0.5,
        label.vjust = -4.5
      )
    ) +
    theme_fig42(tag_margin = margin(-1, -1, -1, -9, "mm")) +
    theme(
      plot.title = element_text(vjust = 0.5, size = 7),
      plot.margin = margin(1, 1, 1, 1, "mm"),
      axis.title.x = element_blank(),
      axis.text.x = element_text(size = 6),
      legend.position = "none",
      legend.title = element_text(size = 6),
      legend.text = element_text(size = 6),
      legend.key.size = unit(3, "mm"),
      legend.spacing.x = unit(1, "mm"),
      legend.spacing.y = unit(0, "mm")
    )
  if (i == 1) {
    themed_plt <- themed_plt +
      theme(axis.text.y = element_text(size = 6)) +
      labs(tag = tag, y = y)
  } else {
    themed_plt <- themed_plt +
      theme(axis.text.y = element_blank()) +
      labs(y = " ")
  }
  return(themed_plt)
}

cancers <- c("COAD", "LUAD", "MM", "PAAD")
panel_C_plots <- paste0(
  cancers,
  "_mutational-signatures-distribution-by-allele"
)

panel_C <- lapply(panel_C_plots, read_fig_proto) %>%
  imap(
    style_mutsig_prob_barplots,
    tag = "c",
    y = "avg. signature composition"
  ) %>%
  wrap_plots(nrow = 1, widths = mutsig_barplot_widths)

pull_wrapped_plot_data(panel_C, cancer, cancers) %>%
  relocate(cancer, everything()) %>%
  save_figure_source_data(figure = FIGNUM, panel = "c")


#### ---- D. Mutational signatures probability of causing KRAS allele ---- ####
# The probability that each allele was caused by each detectable mutational
# signature.
# original script: "src/50_30_mutsignatures_prob-causing-allele.R"

panel_D <- read_fig_proto("probability-mutsig-caused-allele_barplot-list") %>%
  imap(style_mutsig_prob_barplots,
    tag = "d",
    y = "probability of causing allele"
  )


pull_signatures_from_panel_D <- function(x) {
  ggplot_build(x)$plot$data %>%
    filter(prob_sum > 0) %>%
    u_pull(description)
}

signatures <- map(panel_D, pull_signatures_from_panel_D) %>%
  unlist() %>%
  unique() %>%
  sort() %>%
  as.character()

signatures_label_df <- tibble(
  signatures,
  etiology = c(
    "clock", "", "", "tobacco\nsmoke", "clock", "", "Pol η",
    "", "oxidative\nstress", "ROS", "", "", ""
  )
)

signatures_label_df <- bind_cols(
  signatures_label_df,
  custom_label_legend_df(signatures_label_df$signatures)
)

white_lbls <- c("5", "9", "18", "MSI")
signatures_label_df$color[signatures_label_df$lbl %in% white_lbls] <- "white"


panel_D_legend <- custom_label_legend_plot(
  signatures_label_df,
  y_value = "signature",
  family = "Arial",
  size = 1.8,
  label.padding = unit(1, "mm"),
  label.size = unit(0, "mm"),
  hjust = 0.5
) +
  scale_fill_manual(values = mutsig_descrpt_pal) +
  theme(
    legend.position = "none",
    plot.margin = margin(-10, 0, 0, 0, "mm"),
    axis.text.y = element_text(size = 6, family = "Arial")
  )


panel_D_legend_etiology <- signatures_label_df %>%
  mutate(signatures = fct_inorder(signatures)) %>%
  ggplot(aes(x = mid, y = "etiology")) +
  geom_text(aes(label = etiology, color = signatures),
    family = "Arial", size = 1.8, hjust = 0.5, fontface = "bold"
  ) +
  scale_color_manual(values = mutsig_descrpt_pal) +
  scale_x_continuous(
    limits = c(
      min(signatures_label_df$start),
      max(signatures_label_df$end)
    ),
    expand = c(0, 0)
  ) +
  theme_void(base_size = ) +
  theme(
    legend.position = "none",
    plot.margin = margin(0, 0, -5, 0, "mm"),
    axis.text.y = element_text(size = 6, family = "Arial")
  )

panel_D <- wrap_plots(panel_D, nrow = 1, widths = mutsig_barplot_widths)

pull_wrapped_plot_data(panel_D, cancer, cancers) %>%
  relocate(cancer, everything()) %>%
  save_figure_source_data(figure = FIGNUM, panel = "d")


#### ---- Figure assembly ---- ####

{
  set.seed(0)

  # COMPLETE FIGURE
  row_1 <- (panel_A | panel_B) +
    plot_layout(widths = c(3, 10))

  panel_D_legend_sp <- (
    plot_spacer() |
      (panel_D_legend / panel_D_legend_etiology) |
      plot_spacer()
  ) +
    plot_layout(widths = c(1, 4, 1))

  row_2 <- (panel_C / panel_D / panel_D_legend_sp) +
    plot_layout(heights = c(3, 3, 1))

  row_2 <- wrap_elements(full = row_2)

  full_figure <- (row_1 / row_2) +
    plot_layout(heights = c(3, 10))

  save_figure(
    full_figure,
    figure_num = FIGNUM,
    dim = FIG_DIMENSIONS
  )
}
