# Figure 020. "Increased expression of WDR26 has previously been
# implicated in driving breast cancer by serving as a scaffolding protein in
# the PI3K-Akt pathway, though there does not appear to be a link between RNA
# levels and genetic dependency in the COAD cell lines"

FIGNUM <- 20

# > SET THE FIGURE DIMENSIONS
FIG_DIMENSIONS <- get_figure_dimensions(2, "short")
FIG_DIMENSIONS$height <- 80


theme_fig20 <- function() {
  theme_comutation() %+replace%
    theme(
      plot.tag = element_text(
        size = 7,
        face = "bold",
        margin = margin(-1, -1, -1, -1, "mm")
      )
    )
}


#### ---- A. WDR26 dependency by mRNA expression ---- ####
# A scatter plot of WDR26 dependency by mRNA expression in COAD
# original script: "src/10_57_coad_depmap_wdr26.R"

panel_A <- read_fig_proto("coad_depmap_wdr26-rna-v-dep.svg") +
  scale_size_manual(values = c("norm" = 3, "amp" = 5)) +
  theme_fig20() +
  theme(
    legend.title = element_markdown(size = 6),
    legend.text = element_markdown(size = 6),
    axis.title.x = element_markdown()
  ) +
  labs(
    color = "*KRAS* allele"
  )


#### ---- Figure assembly ---- ####

{
  # COMPLETE FIGURE
  full_figure <- (plot_spacer() | panel_A | plot_spacer()) +
    plot_layout(widths = c(2, 3, 2))

  save_figure(
    full_figure,
    figure_num = FIGNUM,
    dim = FIG_DIMENSIONS
  )
}
