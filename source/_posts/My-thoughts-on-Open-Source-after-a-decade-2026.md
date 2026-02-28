---
title: My Thoughts on the Open Source — after a decade
date: 2026-02-17 18:23:00
tags:
- Open Source
- Linux
categories:
- Open Source
- Dairy
---

    You can find the original version in Chinese here: https://blog.inoki.cc/2026/02/17/My-thoughts-on-Open-Source-after-10-years-2026-cn/

It has been over twenty years since the first edition of *The Cathedral and the Bazaar*. In 1997, during the early days of the open source movement, that book offered a highly suggestive metaphor: software development is like building—it can be cathedral-style or bazaar-style. Cathedral-style development is carefully designed and built by a few, emphasizing planning and order; bazaar-style development is open and decentralized, emphasizing trial-and-error and fast iteration.

Back then, Eric S. Raymond was describing how the same codebase, under different ways of organizing, could turn into very different things: in the cathedral, it was a work polished behind closed doors by a handful of “elite architects”; in the bazaar, it was something shaped by stall-keepers and passers-by through constant experimentation. The cathedral stressed order, planning, and a unified vision; the bazaar stressed collision, trial-and-error, and fast feedback. The two modes later became almost a metaphor for “elite open source collaboration” and “distributed open source collaboration.”

Across a very wide range of examples, we do see both modes. But over time, the landscape of the open source world has changed a lot. We can still use cathedral and bazaar to describe different projects—GNU is cathedral, Linux is bazaar; BSD is cathedral, Apache is bazaar; Emacs is cathedral, Perl is bazaar—and this dichotomy was very persuasive in the open source world of the time and became a basic framework for many people. The boundary between them, however, has blurred.

More than twenty years on, the software world looks intensely “open-sourced”: repositories on GitHub grow exponentially, and infrastructure like Linux, Python, and Node.js dominates almost everything. But if we shift our view from licenses to *how people collaborate*, I see that we no longer live in the simple cathedral / bazaar binary world Raymond imagined.

# The Evolution of Open Source

The earliest generation of open source hackers was driven by interest and reputation; they wrote code for their peers and hoped everyone could use software freely.

Today, many projects are born with product and business goals from day one—cloud vendors, SaaS companies, and AI labs use open source for branding, ecosystems, and distribution. The result is that governance often looks more like a company managing its product line than a community maintaining a common good. The well-known open source enthusiast @tison1096 (tisonkun) in the Chinese community has written about the “bait-and-switch” of open source: attract users with a permissive license, then switch to a more closed commercial license and leave behind a “memorial” old repo; the paths of MongoDB and Elastic are often cited as textbook cases. There is recently MinIO as well.

In the AI era, we also see “weights-only open” models: weights are open, data and training recipes are closed. The community can run and fine-tune, but has a hard time participating in the evolution of the model itself; Llama and open models from Chinese LLM companies are often discussed in this context.

Of course, in a world where capitalism is dominant, “working for little or no reward” has become a neutral or even negative phrase. Everyone in high-tech is talking about ARR, fundraising, stock options, etc. Developers and companies need to make money too, and open source should not be synonymous with unpaid labor—as the Tailwind CSS team showed in an issue: they had to let go of 75% of their maintainers (in practice, 3 out of 4 people) because they ran out of funding.

In the GitHub Accelerator training I participated in (a great thank to Gregg Cochran), there was a lot of content on how to commercialize open source. I am not against that (at all); I only want to share some observations and reflections on how open source has evolved over this decade, especially from the angle of collaboration—what has changed in the open source world, and what those changes mean for participants.

# Cathedral, Bazaar, and the Street Stall

If the cathedral is a “fully fitted office building” and the bazaar is a “planned commercial street,” then many open source projects in the years after GitHub’s rise are closer to “night-market stalls”:

- Anyone can put up a repo, slap on an open source license, and call it “open for business”;
- You never know what the maintainer will serve tomorrow;
- Maintainers might push an update when they’re in the mood today and vanish tomorrow at little cost;
- Users who are satisfied might buy a coffee; those who aren’t might complain in public;
- The bar to join this “stall economy” is relatively low—a bit of git, opening issues and PRs is enough.

Of course, some stall-keepers later grow their operation and upgrade to a proper shop (open an org), and it may turn into something more like a bazaar; but many stalls remain one-off, low-bar, full of trial-and-error and chance.

I’m willing to call this, alongside cathedral and bazaar, the “open source street-stall mode”, and I think it has contributed greatly to GitHub’s boom.

Why introduce a new, and even somewhat “low-end,” category? Because the “bazaar”—those stable, multi-party, large projects—has seen its bar rise. Just like a real bazaar, it requires stall-keepers with some resources and the ability to keep supply and stall going over time. In the open source world, that means stable maintainers, clear roadmaps, and strict code review. All of that favors experienced people with time and an understanding of community norms, not newcomers who drop a patch in passing.

## The Bazaar’s Drying Up of Fluidity

The story of Asahi Linux is a concrete example of how this structure can push people away. Project lead Hector Martin was tackling the hard problem of Apple Silicon while fighting for space for Rust drivers in the kernel community, and in the end he stepped down first as a kernel maintainer, then as Asahi project lead, stating publicly that he had “completely lost confidence in the kernel development process and community management.”

The triggers he described in his long post are typical:
- On one side, exhaustion from years of maintenance and the gap between user expectations and actual support;
- On the other, the tug-of-war around Rust for Linux—support in public, eye-rolling in private, technical issues caught up in cultural and power dynamics.

When the interior side of the “bazaar” becomes a place that only welcomes old hands, is highly defensive about new tech, and harsh on newcomers, it may still look like a bazaar from the outside, but internally it runs more and more like small cathedrals—with their own rules, hierarchy, and barriers, even exclusivity. For anyone who wants to participate and contribute, such an environment is discouraging.

I have my own example. In 2019 I tracked down a bug in the AX88179/178a USB Ethernet driver, wrote a long post documenting the behavior, reproduction steps, and fix approach, and sent a patch—only to hear nothing in my inbox for a long time. The issue wasn’t obscure: later, release notes for openSUSE and other distros showed the same device and symptoms reported elsewhere; in 2020 the fix was merged by the networking subsystem maintainer in commit e869e7a17798d85829fa7d4f9bbe1eebd4b2d3f6, using a similar approach. From a system perspective it was a “success”: someone found the bug, someone gave clues, someone merged the patch. From a participant’s perspective it felt more like one-way output: I did the full investigation and validation but had neither the interest nor the energy to maintain mailing-list relationships just to make “who submits this patch” a nicer story. I enjoy the act of creating—finding bugs, writing analysis, doing feature-based PRs—more than pinging people, chasing progress, and mediating between maintainers.

## Maintainer Burnout

That said, it’s understandable. Maintainers of open source projects, especially core maintainers, are often volunteers or part-time; they put a lot of time and effort into maintaining projects on top of their jobs, and that load grows with project size and complexity.

The Linux kernel is an extreme case. The maintainer list is long and governance is highly distributed, but LWN’s coverage and research keep pointing out: patch volume keeps rising, while the people who actually have decision power and can push are only a few dozen to a hundred. A patch from submission to mainline often goes through multiple rounds of review, rebase, and cross-validation, on a timescale of months. The maintainer of the memory management (mm) subsystem, @silsrc, has complained on X (Twitter) about how long things take. This is widespread in many large open source projects: maintainers handle merges, issues, mailing-list discussions, plus overall planning and technical direction—all of which take substantial time and energy.

For maintainers this means real manual and emotional labor: reviewing and writing code, releasing, handling security, plus explaining decisions on the list, mediating disputes, and accommodating newcomers’ learning curves.

For contributors it shows up as a rising bar:

- You need to know git, mailing-list etiquette, and the implicit rules of subsystems;
- You need to be willing to wait months for review, keep rewriting based on feedback, and sometimes accept “this direction doesn’t work” and start over.

Depending on the maintainer, there can also be credit disputes—there’s a story on Reddit about a Linux kernel maintainer rejecting a patch for code quality and then submitting another commit to fix the same issue.

In other words, the bazaar is still there, but the bar to get a stall is higher and higher; those who make it into the community have already been filtered many times.

# Ties to Personal and Corporate Interests

More and more open source contribution and maintenance is tied to personal career development and corporate business interests. For individuals, participating in open source has become an important part of career development: it can improve skills, increase visibility, and even lead to job offers. For companies, open source has become a tool for branding, ecosystem building, and marketing: it attracts the attention and participation of the developer community and strengthens product competitiveness and user stickiness. I think this overlap of interests is to some extent inevitable: open source is now a mainstream way of building software, and participating in it is a major path for career growth, so the boundaries naturally blur.

Personally I enjoy more the process of a group of people with shared interests coming together, bouncing off ideas, code, and builds—rather than fixing endless bugs and doing long-term maintenance. I want to deliver outcomes tied to features, not how many PRs were merged or how many lines changed (on GitHub, when maintainers merge a PR with a squash commit, the lines changed in the original PR are attributed to the maintainer). So I’ve kept my distance from various SIGs, TCs, PMCs—work is work, open source is open source; they can overlap, but I don’t want them to fully coincide. I’ve also long felt that SIG should emphasize “Interest” as in interest group, not the “interest” that most SIGs effectively pursue on behalf of companies or organizations, even though in English the word is the same.

In this section I want to share some phenomena and thoughts from this decade, especially from the perspective of an individual participant.

## Contribution Can Be Quantified—And the Problems Come From That Too

In the early days of open source, how to measure contribution was vague: fixing a bug? Writing docs? Proposing an idea? Being active in the community? Any of these could count, but there was no single, quantified metric. As open source became more commercial and professional, contribution started to be quantified: number of PRs, commits, issues, lines of code—all became indicators of how much someone contributed. That has some benefits: it gives an objective standard, encourages participation, and helps maintainers spot active contributors. But it also causes problems: it can encourage quantity over quality, “PR farming,” and it can overlook genuinely valuable contributions that don’t fit the metrics.

A domestic example in China is Huawei—@mawei_spoiler (maweiwei) on X (Twitter) has criticized “KPI-driven open source contribution,” which drew a lot of discussion—their senior Linux maintainers also submit typo fixes to keep commit count up and meet company performance targets. Of course that’s understandable too: in a system oriented around metrics, maintainers may feel they have to keep a certain submission rate to prove their worth, or be seen as inactive or less valuable. Those of us who do open source purely out of interest may look down on typo fixes as meaningless or even ridiculous, but for people who need to prove their value through open source contribution at work, it can be a survival strategy.

There are plenty of international examples too. Many projects create “good first issue” tasks to encourage participation—usually simple, beginner-friendly work. But some people chase these without regard for quality, or submit pointless PRs just to get “contribution” credit. That’s another side of quantification: it can incentivize quantity over quality. Events like Hacktoberfest have been criticized for encouraging “PR farming” because rewards are tied to submission count rather than quality.

By contrast, programs like Google Summer of Code (GSoC) focus more on quality: participants submit a full project proposal and work continuously over the summer with communication; in the end mentors evaluate the quality and impact of the contribution, not just submission count. I’ve been a GSoC student twice and a mentor once, and I think this model is better: it encourages participants to think deeply and design a meaningful project rather than chase quantitative achievement, and it offers a more structured path for learning and growth so they can really understand and join the community. I may have been too strict—as someone from a culture that can be harsh—and once failed a student at the final evaluation for insufficient completion; after working in the industry I’ve become more forgiving and think that as long as they learned and built actively along the way, that’s valuable. I apologize here to the student I failed. Of course this model has limits too: it depends heavily on proposal quality and mentor judgment (with no unified standard), and can exclude people with potential who aren’t good at writing proposals.

So contribution can be quantified, but the problems lie in quantification too. We need a balance: encourage participation while ensuring the quality and value of contributions.

## The Middleman

In a world where “contribution can be quantified,” another role inevitably appears—I’ll call it the middleman. The typical script: someone painstakingly tracks down a problem in an issue, documents reproduction, cause, and workaround, intending to clarify the direction before discussing a long-term solution; before the discussion even starts, someone else packages that same idea into a clean PR and puts their name on it first.

The PR area is what shows up most on the stats: it decides who is “top contributor,” who gets badges, who can put that line on their résumé. The issue area is more like a real free bazaar: trial and error, debate, gradual consensus, and explorations that never became patches. The system isn’t malicious, but the default accounting keeps rewarding “who opened the PR,” not “who actually figured out the problem.” So we see a division of labor in the collaboration chain: some people work at the stall to find what works; others take that experience, package it, and turn it into “contribution” that counts toward KPI.

I ran into this recently on the vLLM project. I had analyzed a problem I hit in an issue in detail, with reproduction and workaround, intending to discuss slowly with maintainers and see if we could design a better long-term solution. Soon a PR appeared from someone that largely followed the issue’s approach and adopted (not even adapted) the workaround into a mergeable patch. Classic scenario: the people getting their hands dirty in the issue did the experimentation; the PR was more like a small wholesale stall next door, packaging that experience as “quantifiable contribution.”

I shared this on X (Twitter); some people went after that contributor. I don’t think that was necessary—I can understand: in a system driven by PR count, he may have felt he needed to submit a PR to prove his contribution, maybe to say on his résumé that he contributed to vLLM and help his job search in the AI era. After similar things happened a few times, I at least learned to use the rules: since the system keeps the books by “name on the PR,” I ask maintainers to add my signed-off-by when merging, so I get at least some of the credit back. Of course that depends on the maintainer’s attitude and habits; if they won’t add my signed-off-by, I have to accept that.

This doesn’t change the collaboration model itself, but it makes the value chain a bit clearer: from problem investigation to workaround to patch packaging and final decision, someone is putting in work at each step—only in the past, only the last step was recorded by the system.

# The AI Era: Back Toward the Cathedral

AI-driven vibe coding has made open source more subtle. On the surface, vibe coding lowers the bar: newcomers can talk to a model and get a chunk of “looks like it runs” code; many tutorials even claim you can build products without knowing how to program. But once you’re in a real team, especially in an internal cathedral-style vibe coding workflow, newcomers find the bar is actually higher: senior engineers and the model do high-frequency refactoring in private repos, code evolves very fast, but there’s little in the way of teaching material—no fine-grained commit history, no design docs written for newcomers, just code that has grown to its current state and a few hard-to-replay conversation logs. GitHub’s former co-founder started a company to try to address this, offering a “git log for vibe coding,” but that’s only a patch; the real challenge is: in the AI era, how do we design an open source collaboration model that fits how newcomers learn and grow?

In traditional open source, newcomers could at least start with good first issues, doc fixes, small bugs, and work their way toward the core. In the internal vibe coding world, many “middle steps” are skipped by AI, and the learning path left behind is steeper: you have to learn to read and modify complex AI-generated code while lacking low-risk practice settings.

This aligns with many people’s worries about junior developers in the vibe coding era: when AI can easily do a lot of basic programming, juniors may feel they have nothing to contribute, or even that they’re being replaced. It’s a real issue: if maintainers and core contributors are using AI to speed up development, those without AI access or familiarity may feel they can’t keep up.

If we add the commercial open source model on top, another question appears: when companies can use AI to fix bugs and add features quickly internally, will more change happen inside the cathedral, and will external open source contributions be accepted less? The fact that GitHub introduced a “feature to close PRs” is a significant sign of this.

In that sense, vibe coding strengthens the cathedral inside companies—making that building grow faster, taller, and more complex—while the bazaar and stalls outside are more like its shadow: people in the shadow imitate the shape of the beams and columns but can never reach those who really decide the structure; unless you join the cathedral from within, you can only grope in the shadow.

# Closing

The open source world has changed a lot: from early interest-driven, community collaboration to today’s commercialization and professionalization, and possibly future AGI shifts. We’re seeing a series of new patterns and challenges. The cathedral and bazaar metaphor is still useful, but it can’t fully capture the complexity of open source today.

Whether cathedral, bazaar, or street stall, each mode has its value and limits. We need to use them flexibly in different situations, and also be wary of trends that could lead to exclusivity, over-commercialization, or technical monopoly. The future of open source is still full of possibilities, and each of us is shaping it.

When vibe coding makes so many things within reach, doing what only humans can do—building, designing, deciding, even community management—becomes more important. We need to ask: in the AI era, what kind of open source collaboration can truly foster innovation, inclusion, and sustainability? And how do we find our place in this new world and keep contributing to open source?

I hope we don’t throw out the baby with the bathwater—don’t give up on open source and free software because of its problems. Keep exploring and moving forward on the open source path. Whether as maintainers, contributors, or users, we can find value and joy in this evolving world that is truly our own, not just what the social evaluation system assigns. Cheers for the future anyway!

# References

Here are some links mentioned in the post. Since this isn’t a formal paper, they’re not in strict academic format; I’ll add any I missed over time:

- Eric S. Raymond, “The Cathedral and the Bazaar”.
http://www.catb.org/esr/writings/cathedral-bazaar/

- Tison Kung, “诱导转向的伪开源战略（Bait-and-Switch Fauxpen Source Strategy）” [Bait-and-Switch Fauxpen Source Strategy].
https://www.tisonkun.org/2022/10/04/bait-and-switch-fauxpen-source-strategy/

- Jimmy Song, “大模型时代的开源：从开放代码到开放权重的演进” [Open Source in the LLM Era: From Open Code to Open Weights].
https://jimmysong.io/zh/book/ai-handbook/llm/open-model/

- Air Street Press, “The cathedral and the bazaar – how AI rewrites open vs. closed”.
https://press.airstreet.com/p/the-cathedral-and-the-bazaar

- LWN.net, “Reducing kernel-maintainer burnout”.
https://lwn.net/Articles/952666/

- LWN.net, “On Linux kernel maintainer scalability”.
https://lwn.net/Articles/703005/

- LWN.net, “MAINTAINERS truth and fiction”.
https://lwn.net/Articles/842415/

- Intel, “Maintainer Burnout is a Problem. So, What Are We Going to Do?”
https://www.intel.com/content/www/us/en/developer/articles/community/maintainer-burnout-a-problem-what-are-we-to-do.html

- Hector Martin, “Resigning as Asahi Linux project lead”.
https://marcan.st/2025/02/resigning-as-asahi-linux-project-lead/

- The Register, “Asahi Linux head quits, citing kernel leadership failure”.
https://www.theregister.com/2025/02/13/ashai_linux_head_quits/

- Inoki’s blog: AX88179/178a USB-Ethernet adapter Linux Driver
https://blog.inoki.cc/2019/12/12/Bug_AX88179_178a_USB_Ethernet_adapter_Linux_Driver/

- Linux commit fixing AX88179/178a tailing 2-byte: e869e7a17798d85829fa7d4f9bbe1eebd4b2d3f6.
https://github.com/torvalds/linux/commit/e869e7a17798d85829fa7d4f9bbe1eebd4b2d3f6

- vLLM Issue #31901
https://github.com/vllm-project/vllm/issues/31901

- vLLM PR #32384
https://github.com/vllm-project/vllm/pull/32384

- How I got robbed of my first kernel contribution
https://www.reddit.com/r/programming/comments/16tf5ne/how_i_got_robbed_of_my_first_kernel_contribution/
