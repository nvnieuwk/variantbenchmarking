//
// SV_GERMLINE_BENCHMARK: SUBWORKFLOW FOR SV GERMLINE VARIANTS
//

include { TRUVARI_BENCH          } from '../../modules/nf-core/truvari/bench'
include { SVANALYZER_SVBENCHMARK } from '../../modules/nf-core/svanalyzer/svbenchmark'
include { WITTYER                } from '../../modules/nf-core/wittyer'
include { TABIX_BGZIP as TABIX_BGZIP_QUERY } from '../../modules/nf-core/tabix/bgzip'
include { TABIX_BGZIP as TABIX_BGZIP_TRUTH } from '../../modules/nf-core/tabix/bgzip'
include { VCF_REHEADER_SAMPLENAME as VCF_REHEADER_SAMPLENAME_1 } from '../local/vcf_reheader_samplename'
include { VCF_REHEADER_SAMPLENAME as VCF_REHEADER_SAMPLENAME_2 } from '../local/vcf_reheader_samplename'
include { VCF_REHEADER_SAMPLENAME as VCF_REHEADER_SAMPLENAME_3 } from '../local/vcf_reheader_samplename'
include { VCF_REHEADER_SAMPLENAME as VCF_REHEADER_SAMPLENAME_4 } from '../local/vcf_reheader_samplename'

workflow SV_GERMLINE_BENCHMARK {
    take:
    input_ch  // channel: [val(meta),test_vcf,test_index,truth_vcf,truth_index, bed]
    fasta     // reference channel [val(meta), ref.fa]
    fai       // reference channel [val(meta), ref.fa.fai]

    main:

    versions=Channel.empty()
    summary_reports=Channel.empty()
    tagged_variants=Channel.empty()

    // SV benchmarking
    if (params.method.contains('truvari')){
        //
        // MODULE: TRUVARI_BENCH
        //
        TRUVARI_BENCH(
            input_ch,
            fasta,
            fai
        )
        versions = versions.mix(TRUVARI_BENCH.out.versions)

        TRUVARI_BENCH.out.summary
            .map { meta, file -> tuple([vartype: meta.vartype] + [benchmark_tool: "truvari"], file) }
            .groupTuple()
            .set { report }

        summary_reports = summary_reports.mix(report)

        VCF_REHEADER_SAMPLENAME_1(
            TRUVARI_BENCH.out.fn_vcf,
            fai
            )

        VCF_REHEADER_SAMPLENAME_1.out.ch_vcf
            .map { meta, file, index -> tuple([vartype: meta.vartype] + [tag: "FN"] + [id: "truvari"], file) }
            .set { vcf_fn }

        VCF_REHEADER_SAMPLENAME_2(
            TRUVARI_BENCH.out.fp_vcf,
            fai
            )

        VCF_REHEADER_SAMPLENAME_2.out.ch_vcf
            .map { meta, file, index -> tuple([vartype: meta.vartype] + [tag: "FP"] + [id: "truvari"], file) }
            .set { vcf_fp }

        VCF_REHEADER_SAMPLENAME_3(
            TRUVARI_BENCH.out.tp_base_vcf,
            fai
            )

        VCF_REHEADER_SAMPLENAME_3.out.ch_vcf
            .map { meta, file, index -> tuple([vartype: meta.vartype] + [tag: "TP_base"] + [id: "truvari"], file) }
            .set { vcf_tp_base }

        VCF_REHEADER_SAMPLENAME_4(
            TRUVARI_BENCH.out.tp_comp_vcf,
            fai
            )

        VCF_REHEADER_SAMPLENAME_4.out.ch_vcf
            .map { meta, file, index -> tuple([vartype: meta.vartype] + [tag: "TP_comp"] + [id: "truvari"], file) }
            .set { vcf_tp_comp }

        tagged_variants = tagged_variants.mix(vcf_fn)
        tagged_variants = tagged_variants.mix(vcf_fp)
        tagged_variants = tagged_variants.mix(vcf_tp_base)
        tagged_variants = tagged_variants.mix(vcf_tp_comp)

    }

    if (params.method.contains('svanalyzer')){
        //
        // MODULE: SVANALYZER_SVBENCHMARK
        //
        // slower than truvari
        SVANALYZER_SVBENCHMARK(
            input_ch,
            fasta,
            fai
            )
        versions = versions.mix(SVANALYZER_SVBENCHMARK.out.versions)

        SVANALYZER_SVBENCHMARK.out.report
            .map { meta, file -> tuple([vartype: meta.vartype] + [benchmark_tool: "svbenchmark"], file) }
            .groupTuple()
            .set{ report}

        summary_reports = summary_reports.mix(report)

        SVANALYZER_SVBENCHMARK.out.fns
                    .map { meta, file -> tuple([vartype: meta.vartype] + [tag: "FN"] + [id: "svbenchmark"], file) }
            .set { vcf_fn }

        SVANALYZER_SVBENCHMARK.out.fps
                    .map { meta, file -> tuple([vartype: meta.vartype] + [tag: "FP"] + [id: "svbenchmark"], file) }
            .set { vcf_fp }
        tagged_variants = tagged_variants.mix(vcf_fn)
        tagged_variants = tagged_variants.mix(vcf_fp)

    }
    if (params.method.contains('wittyer')){

        TABIX_BGZIP_QUERY(
            input_ch.map{it -> tuple(it[0], it[1])}
        )
        versions = versions.mix(TABIX_BGZIP_QUERY.out.versions)

        TABIX_BGZIP_TRUTH(
            input_ch.map{it -> tuple(it[0], it[3])}
        )
        versions = versions.mix(TABIX_BGZIP_TRUTH.out.versions)
        bed = input_ch.map{it -> tuple(it[0], it[5])}

        //
        // MODULE: WITTYER
        //
        WITTYER(
            TABIX_BGZIP_QUERY.out.output.join(TABIX_BGZIP_TRUTH.out.output).join(bed)
        )
        versions = versions.mix(WITTYER.out.versions)

        WITTYER.out.report
            .map { meta, file -> tuple([vartype: meta.vartype] + [benchmark_tool: "wittyer"], file) }
            .groupTuple()
            .set{ report}
        summary_reports = summary_reports.mix(report)

    }

    emit:
    tagged_variants
    summary_reports
    versions
}
