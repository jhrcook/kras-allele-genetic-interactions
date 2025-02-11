
# Analyze the comutation interaction networks at a high level.

GRAPHS_DIR <- "20_40_highlivel-genetic-interactions"
reset_graph_directory(GRAPHS_DIR)


#### ---- UpSetR plot for similarity of alleles ---- ####

# Make UpSetR plots for data nested by `cancer` and `genetic_interaction`
allele_gene_interaction_upsetr <- function(cancer, genetic_interaction, data) {
  gl <- data %>%
    group_by(allele) %>%
    summarise(genes = list(hugo_symbol)) %>%
    deframe()
  save_path <- plot_path(
    GRAPHS_DIR,
    as.character(glue("{cancer}_{genetic_interaction}_upset.svg"))
  )

  sizes <- c(8, 6)
  nsets <- n_distinct(names(gl))

  p <- upset(fromList(gl), nsets = nsets, nintersects = NA, order.by = "freq")
  svg(file = save_path, width = sizes[[1]], height = sizes[[2]])
  print(p)
  dev.off()
}

caps <- as.list(capabilities())
if (caps$X11) {
  info(logger, "Making UpSet plots for each cancer and genetic interactions.")

  library(UpSetR)

  genetic_interaction_df %>%
    select(cancer, allele, hugo_symbol, genetic_interaction) %>%
    unique() %>%
    group_by(cancer, genetic_interaction) %>%
    nest() %>%
    pwalk(allele_gene_interaction_upsetr)
}



#### ---- Make high-level network images ---- ####

cache("genetic_interaction_gr",
  depends = "genetic_interaction_df",
  {
    genetic_interaction_gr <- genetic_interaction_df %>%
      select(hugo_symbol, kras_allele, cancer, p_val, genetic_interaction) %>%
      unique() %>%
      mutate(from = kras_allele, to = hugo_symbol) %>%
      filter(str_replace_us(kras_allele) %in% names(allele_palette)) %>%
      as_tbl_graph() %N>%
      mutate(is_kras = str_detect(name, "KRAS_"))
    return(genetic_interaction_gr)
  }
)


goi_genes <- unique(genes_of_interest_df$hugo_symbol)


# Manual adjustments to some nodes in the plots for figures.
adjust_layout_manually <- function(layout, CANCER, type_of_plot) {
  layout_attrs <- attributes(layout)

  msg <- glue("Manually adjust '{type_of_plot}' network plot for {CANCER}")


  if (CANCER == "COAD" & type_of_plot == "high-unlabeled") {
    message(msg)
    layout <- layout %>%
      mutate(x = case_when(
        name %in% c("KRAS_Q61H", "LRP2", "CACNA1E") ~ x - 3,
        TRUE ~ x
      ))
  } else if (CANCER == "MM" & type_of_plot == "high-labeled") {
    message(msg)
    layout <- layout %>%
      mutate(x = ifelse(node_label == "DNAH10", x + 0.6, x))
  }

  attributes(layout) <- layout_attrs
  return(layout)
}


# Plots the genetic interaction networks.
# A custom layout can be provided using `ggraph::create_layout()`.
make_network_plot <- function(gr, cancer, gr_layout = "nicely",
                              type_of_plot = "high-unlabeled",
                              fill_na_val = NA) {
  set.seed(0)
  custom_layout <- create_layout(gr, layout = gr_layout)
  custom_layout <- adjust_layout_manually(
    layout = custom_layout,
    CANCER = cancer,
    type_of_plot = type_of_plot
  )

  p <- ggraph(custom_layout) +
    geom_edge_link(
      aes(color = genetic_interaction),
      width = 0.3
    ) +
    scale_edge_color_manual(
      values = comut_updown_pal,
      guide = guide_legend(
        title = "comutation",
        title.position = "top",
        keywidth = unit(2, "mm"),
        keyheight = unit(1, "mm"),
        ncol = 1,
        label.position = "top",
        order = 2
      )
    ) +
    geom_node_point(
      aes(size = node_point_size),
      color = "grey65"
    ) +
    geom_node_label(
      aes(
        label = node_label,
        fill = node_fill,
        color = node_color,
        size = label_size
      ),
      family = "Arial",
      label.padding = unit(0.1, "lines"),
      label.r = unit(0.1, "lines"),
      label.size = 0
    ) +
    scale_color_identity() +
    scale_fill_manual(
      values = short_allele_pal,
      na.value = fill_na_val,
      guide = FALSE
    ) +
    scale_size_identity() +
    theme_graph(
      base_family = "Arial",
      base_size = 8
    ) +
    theme(
      plot.title = element_blank(),
      legend.position = "bottom"
    )
  return(p)
}


get_plotting_graph <- function(gr, cancer) {
  mod_gr <- gr %E>%
    filter(cancer == !!cancer) %>%
    mutate(
      genetic_interaction = switch_comut_terms(genetic_interaction)
    ) %N>%
    filter(centrality_degree(mode = "all") > 0)
  return(mod_gr)
}


prep_highlevel_unlabeled <- function(gr) {
  mod_gr <- gr %N>%
    mutate(
      node_label = ifelse(is_kras, name, NA),
      node_label = str_remove_all(node_label, "KRAS_"),
      node_fill = node_label,
      node_color = ifelse(node_label %in% kras_dark_lbls,
        "white", "black"
      ),
      node_point_size = centrality_degree(mode = "all"),
      node_point_size = ifelse(node_point_size > 1, 0.05, NA),
      label_size = 1.8
    )
  return(mod_gr)
}


# Make high-level network with only the KRAS alleles labeled.
for (CANCER in sort(unique(genetic_interaction_df$cancer))) {
  set.seed(0)
  gr_plot <- get_plotting_graph(genetic_interaction_gr, CANCER) %>%
    prep_highlevel_unlabeled() %>%
    make_network_plot(cancer = CANCER) +
    labs(
      edge_color = "interaction"
    )
  save_path <- plot_path(
    GRAPHS_DIR,
    as.character(glue("genetic_interaction_network_{CANCER}.svg"))
  )
  ggsave_wrapper(gr_plot, save_path, size = "medium")

  rds_template <- "genetic_interaction_network_{CANCER}"
  saveFigRds(gr_plot, as.character(glue(rds_template)))
}


# Prepare the node characteristics for the labeled plots.
prep_highlevel_labeled <- function(gr, other_label_size = 1) {
  mod_gr <- gr %N>%
    mutate(
      node_label = str_remove_all(name, "KRAS_"),
      node_fill = ifelse(is_kras, node_label, NA),
      node_color = ifelse(node_fill %in% kras_dark_lbls,
        "white", "black"
      ),
      node_point_size = centrality_degree(mode = "all"),
      node_point_size = ifelse(node_point_size > 1, 0.05, 0),
      label_size = ifelse(is_kras, 2, !!other_label_size)
    )
  return(mod_gr)
}


# Make high-level network with all genes labeled for MM.
set.seed(0)
mm_gr_plot <- get_plotting_graph(genetic_interaction_gr, "MM") %>%
  prep_highlevel_labeled(other_label_size = 1.5) %>%
  make_network_plot(
    cancer = "MM",
    type_of_plot = "high-labeled",
    fill_na_val = "grey85"
  ) +
  labs(
    edge_color = "interaction"
  )

saveFigRds(mm_gr_plot, "genetic_interaction_network_labeled_MM")



# Specifically for LUAD (3 separate supplementals):
#   6. increased comutation only.
#   7. reduced comutation for G12C-only interactions
#   8. all reduced comutation except for G12C-only interactions.

# Supplemental 6: increased comutation for LUAD
# gr_plot <- get_plotting_graph(genetic_interaction_gr, "LUAD") %E>%
#     filter(genetic_interaction == "increased") %N>%
#     filter(centrality_degree(mode = "all") > 0) %>%
#     prep_highlevel_labeled() %>%
#     make_network_plot(layout = "stress") +
#     labs(
#         edge_color = "interaction"
#     )
# saveFigRds(gr_plot, "genetic_interaction_increased_network_labeled_LUAD")


# # Supplemental 7: reduced comutation for G12C-only interactions
# g12c_luad_gr <- get_plotting_graph(genetic_interaction_gr, "LUAD") %E>%
#     filter(genetic_interaction == "reduced") %N>%
#     filter(centrality_degree(mode = "all") == 1 | is_kras) %E>%
#     filter(.N()$name[from] == "KRAS_G12C") %N>%
#     filter(centrality_degree(mode = "all") > 0)
# gr_plot <- g12c_luad_gr %>%
#     prep_highlevel_labeled() %>%
#     make_network_plot(layout = "nicely") +
#     labs(
#         edge_color = "interaction"
#     )
# saveFigRds(gr_plot, "genetic_interaction_reduced_G12Conly_network_labeled_LUAD")


# # Supplemental 8: reduced comutation for all but G12C-only interactions
# g12c_only_genes <- as_tibble(g12c_luad_gr, activate="nodes") %>%
#     filter(!is_kras) %>%
#     u_pull(name)
# gr_plot <- get_plotting_graph(genetic_interaction_gr, "LUAD") %E>%
#     filter(genetic_interaction == "reduced") %N>%
#     filter(!name %in% !!g12c_only_genes) %>%
#     filter(centrality_degree(mode = "all") > 0) %>%
#     prep_highlevel_labeled() %>%
#     make_network_plot(layout = "nicely") +
#     labs(
#         edge_color = "interaction"
#     )
# saveFigRds(
#     gr_plot,
#     "genetic_interaction_reduced_notG12Conly_network_labeled_LUAD"
# )




#### ---- Correlate number of interactors KRAS allele frequency ---- ####

interaction_counts_data <- genetic_interaction_df %>%
  mutate(allele_freq = ifelse(
    genetic_interaction == "comutation",
    allele_freq,
    num_samples_per_cancer_allele / num_samples_per_cancer
  )) %>%
  group_by(cancer, allele, allele_freq, genetic_interaction) %>%
  count() %>%
  ungroup()

interaction_counts_plot <- interaction_counts_data %>%
  filter(n > 0) %>%
  ggplot(aes(x = allele_freq, y = n)) +
  facet_wrap(~cancer, scales = "free") +
  geom_point(aes(color = allele, shape = genetic_interaction)) +
  scale_color_manual(values = short_allele_pal) +
  scale_shape_manual(values = c(0, 2)) +
  scale_x_continuous(limits = c(0, NA)) +
  scale_y_continuous(
    breaks = integer_breaks(),
    limits = c(0, NA)
  ) +
  theme_bw(base_size = 8, base_family = "Arial") +
  theme(
    plot.title = element_text(hjust = 0.5),
    strip.background = element_blank()
  ) +
  labs(
    title = "Association of allele frequency and number of interactors",
    x = "KRAS allele frequency",
    y = "number of genetic interactors",
    color = "allele",
    shape = "interaction"
  )
save_path <- plot_path(
  GRAPHS_DIR,
  "corr_allele-freq_num-interactors.svg"
)
ggsave_wrapper(interaction_counts_plot, save_path, "medium")
